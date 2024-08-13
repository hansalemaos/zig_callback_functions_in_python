import cv2

from locate_pixelcolor_zig import find_rgba_colors
import numpy as np
import cv2
import time

picx = r"C:\Users\hansc\Downloads\imgaspng\pexels-alex-andrews-2295744.png"
pic = cv2.imread(picx, cv2.IMREAD_UNCHANGED)
if not pic.flags["C_CONTIGUOUS"]:
    pic = np.ascontiguousarray(pic)
colors0 = np.array(
    [(255, 255, 255, 255)],
    dtype=np.uint8,
)

start = time.perf_counter()
resus0 = find_rgba_colors(pic=pic, colors=colors0)
print(time.perf_counter() - start)
