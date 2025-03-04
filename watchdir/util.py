import sys
import time
def exit_with_error(message):
    log(message, "ERROR")
    sys.exit(1)

def log(message, level="INFO"):
    current_time= time.strftime("%m-%d %I:%M:%S")
    print("[{}] [{}] {}".format(level,current_time, message))
