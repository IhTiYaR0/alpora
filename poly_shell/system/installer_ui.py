"""Dependency-free terminal status for real installer phases, never fake progress."""
from contextlib import contextmanager
import os
from pathlib import Path
import sys
import threading
import time


class InstallerUI:
    def __init__(self, stream=None):
        self.stream=stream or sys.stdout
        self.tty=self.stream.isatty() and os.environ.get('TERM','dumb')!='dumb'
        self.colour=self.tty and not os.environ.get('NO_COLOR')
        self.log_path=os.environ.get('ALPORA_INSTALL_LOG')
        self.accent='\033[32m' if self.colour else ''
        self.reset='\033[0m' if self.colour else ''

    def record(self,message):
        if self.log_path:
            with Path(self.log_path).open('a') as output:
                output.write(time.strftime('%H:%M:%S')+' '+message+'\n')

    def line(self,message):
        print(message,file=self.stream,flush=True)
        self.record(message)

    @contextmanager
    def stage(self,index,label):
        self.line('\n'+self.accent+f'  [{index}/6] '+label+self.reset)
        started=time.monotonic();stop=threading.Event()
        def animate():
            frames='|/-\\';frame=0
            while not stop.wait(.12):
                self.stream.write(f'\r    {frames[frame%4]} Working · {int(time.monotonic()-started)}s')
                self.stream.flush();frame+=1
        worker=threading.Thread(target=animate,daemon=True) if self.tty else None
        if worker:worker.start()
        success=False
        try:
            yield
            success=True
        finally:
            stop.set()
            if worker:worker.join();self.stream.write('\r\033[2K')
            result='Done' if success else 'Stopped'
            self.line(f'    {result} · {time.monotonic()-started:.1f}s')
