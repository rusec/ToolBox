import time
import hashlib
from collections import deque
import threading
import datetime
import os
class Logger:
    def __init__(self, debounce_time=2, log_to_console=False, log_file=None):
        """
        Initializes the log debouncer.

        :param debounce_time: Time window (in seconds) within which similar logs are merged.
        """
        self.debounce_time = debounce_time
        self.log_cache = {}
        self.queue = deque()
        self.log_file = log_file
        self.log_to_console = log_to_console
        self.flushing = False

        if log_file:
            if not os.path.exists(os.path.dirname(log_file)):
                os.makedirs(os.path.dirname(log_file))

    def _hash_log(self, message, level):
        return hashlib.md5("{}{}".format(message, level).encode()).hexdigest()

    def _setTimer(self):

        # If a timer is already running, cancel it (takes more memory)
        # maybe keeping the old timer is better for performance
        if self.timer:
            self.timer.cancel()

        self.timer = threading.Timer(self.debounce_time, self._flush)
        self.timer.start()

    # Log the message
    # If the message is already in the cache, increment the count
    # If the message is not in the cache, add it to the cache
    # Time stamp will be added to the log message
    def log(self, message, level="INFO"):
        log_hash = self._hash_log(message, level)
        current_time = time.time()

        if log_hash in self.log_cache:
            self.log_cache[log_hash]['count'] += 1
            self.log_cache[log_hash]['last_seen'] = current_time

        else:
            self.log_cache[log_hash] = {
                'message': message,
                'level': level,
                'count': 1,
                'last_seen': current_time
            }
            self.queue.append(log_hash)

        self._setTimer()
        self._clean_cache()

    def _write_log(self,time_stamp, message, level, count):

        if self.log_to_console:
            if count > 1:
                print("[{}] [{}] {} | [{}]".format(time_stamp, level, message, count))
            else:
                print("[{}] [{}] {}".format(time_stamp, level, message))



        if self.log_file:
            with open(self.log_file, 'a') as f:
                if count > 1:
                    f.write("[{}] [{}] {} | [{}]\n".format(time_stamp, level, message, count))
                else:
                    f.write("[{}] [{}] {}\n".format(time_stamp, level, message))


    def _flush(self, force=False):
        if force:
            self._clean_cache()
            return
        if self.flushing == False:
            return
        self._clean_cache()


    def _clean_cache(self):
        self.flushing = True
        current_time = time.time()
        while self.queue:
            log_hash = self.queue[0]
            log = self.log_cache[log_hash]

            if current_time - log['last_seen'] < self.debounce_time:
                break

            self.queue.popleft()
            log_time = datetime.datetime.fromtimestamp(log['last_seen']).strftime('%Y-%m-%d %H:%M:%S')
            self._write_log(log_time,log['message'], log['level'], log['count'])
            del self.log_cache[log_hash]

        self.flushing = False
