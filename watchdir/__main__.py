#!/usr/bin/env python3
import watchdir
import os

if os.getuid() != 0:
    print("Please run this script as sudo")
    exit(1)

print()

watchdir.main()