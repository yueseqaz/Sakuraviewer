#!/usr/bin/env python3
# demo.py — Python 语法高亮样例
import math


class SakuraTree:
    """樱花树：简单的递归分形。"""

    def __init__(self, depth=5):
        self.depth = depth

    def branches(self, n=1):
        if n > self.depth:
            return []
        return [(n, math.pi * n / 8)] + self.branches(n + 1)


if __name__ == "__main__":
    tree = SakuraTree(depth=4)
    for depth, angle in tree.branches():
        print(f"层 {depth}: 偏转角 {math.degrees(angle):.1f}°")