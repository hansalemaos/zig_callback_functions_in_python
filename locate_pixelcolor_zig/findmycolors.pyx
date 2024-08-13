import cython
cimport cython
import os
import numpy as np
cimport numpy as np
import time, subprocess
from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport pair as cpair
from libcpp.vector cimport vector
from libcpp.string cimport string
import ctypes
import re
import platform


this_folder = os.path.dirname(__file__)
_func_cache = []
subprocess._USE_VFORK = False
subprocess._USE_POSIX_SPAWN = False
iswindows = "win" in platform.platform().lower()
if iswindows:
    addtolist = []
else:
    addtolist = ["&"]

def compile_it(ziglibfile):
    zigpathstr = os.path.normpath(os.path.join(this_folder, ziglibfile))
    winpathstr = re.sub(r'\.zig$','.dll',zigpathstr)
    linuxpathstr = re.sub(r'\.zig$','.so',zigpathstr)
    win_path=os.path.exists(winpathstr)
    linux_path=os.path.exists(linuxpathstr)
    if not os.path.exists(winpathstr) and not os.path.exists(winpathstr) :
        old_folder=os.getcwd()
        os.chdir(this_folder)
        subprocess.run(
        ["zig", "build-lib", ziglibfile, "-dynamic", "-O", "ReleaseFast"]+addtolist,
        shell=True,
        env=os.environ,
        preexec_fn=None
        if iswindows
        else os.setpgrp
        if hasattr(os, "setpgrp")
        else None,
        )
        time.sleep(1)
        if not iswindows:
            time.sleep(20)
        win_path=os.path.exists(winpathstr)
        linux_path=os.path.exists(linuxpathstr)
        os.chdir(old_folder)
    if win_path:
        return winpathstr
    if linux_path:
        return linuxpathstr
    raise OSError('Zig library not found')

ziglibfile='findmycolorszig.zig'
library_path_string=compile_it(ziglibfile)


ctypedef void (*func_t)(size_t save_function , size_t address_pic,
                        size_t address_colors, size_t width, size_t totallengthpic,
                        size_t totallengthcolor, size_t resultdi) noexcept nogil ;

ctypedef void (*func_t2)(unsigned int rgba, unsigned short x, 
                        unsigned short  y, size_t resultdi) noexcept nogil ;
ctypedef cpair[unsigned short, unsigned short] ipair
ctypedef unordered_map[unsigned int, vector[ipair]] rgbresults


cdef func_t get_lookup_dict(str dllpathstr,str zigfunction):
    cta = ctypes.cdll.LoadLibrary(dllpathstr)
    _func_cache.append(cta)
    ctypes_f=getattr(cta, zigfunction)
    return (<func_t*><size_t>ctypes.addressof(ctypes_f))[0]

cdef:
    func_t _find_rgba_colors = get_lookup_dict(
                                dllpathstr=library_path_string,
                                zigfunction='find_rgba_colors',
)
cdef func_t2 py_to_fptr(f,re_arg):
    functype = ctypes.CFUNCTYPE(*re_arg)
    ctypes_f = functype(f)
    _func_cache.append(ctypes_f)
    return (<func_t2*><size_t>ctypes.addressof(ctypes_f))[0]

cdef void append_to_unordered_map(unsigned int rgba, unsigned short  x, 
        unsigned short  y, size_t resultdi) noexcept nogil:
    ((<rgbresults*>resultdi)[0])[rgba].push_back(ipair(x, y))

cdef size_t save_function=<size_t>py_to_fptr(append_to_unordered_map,(None, 
            ctypes.c_uint32,ctypes.c_ushort,ctypes.c_ushort,ctypes.c_size_t))


def find_rgba_colors(np.ndarray pic, np.ndarray colors, 
                    size_t reserve_mem_percent=10,
                    bint return_with_alpha=False):
    cdef:
        unsigned char[:]picview
        unsigned char[:]colorsview
        rgbresults resultdi
    if pic[0][0].shape[0]==3:
        pic=np.dstack([pic, np.full((pic.shape[0],pic.shape[1]), 255, dtype=pic.dtype)])
    if colors[0].shape[0]==3:
        colors=np.concatenate(
        [colors, np.full((colors.shape[0], 1), 255, dtype=colors.dtype)], axis=1
    )
    picview  =pic.ravel()
    colorsview  =colors.ravel()
    resultdi.reserve((colorsview.shape[0] // 100) * reserve_mem_percent)
    resultdi={}
    _find_rgba_colors(
        <size_t>(save_function),
        <size_t>(&picview[0]),
        <size_t>(&colorsview[0]),
        <size_t>(pic.shape[1]),
        <size_t>((pic.shape[0] * pic.shape[1] )),
        <size_t>(colors.shape[0]),
        <size_t>(&resultdi),
    )
    if return_with_alpha:
        return {tuple((k & (0xFF << (i * 8))) >> (i * 8) for i in range(4)):v for k,v in resultdi}
    return {tuple((k & (0xFF << (i * 8))) >> (i * 8) for i in range(3)):v for k,v in resultdi}
