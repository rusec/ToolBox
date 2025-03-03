import sys

def exit_with_error(message):
    log(message, "ERROR")
    sys.exit(1)

def log(message, level="INFO"):
    time = time.strftime("%Y-%m-%d %H:%M:%S")
    print("[{}] [{}] {}".format(level,time, message))


