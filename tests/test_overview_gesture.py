import shutil
import subprocess
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class OverviewGestureTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node is needed for standalone QML JS checks')
    def test_protocol_validation_release_and_momentum(self):
        script = r'''
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const g = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[1], 'utf8').replace(/^\.pragma library\s*/, ''), g);
const message = (phase, distance, time, cancel = 0) => `poly-overview-swipe,v1,test-1,${phase},1,${distance},${time},${cancel}`;
assert.equal(g.parse(message('start', 0, 1000)).phase, 'start');
assert.equal(g.parse(message('finish', 10, 1100, 1)).cancelled, true);
for (const invalid of ['', 'another,v1,x,start,1,0,0,0', message('bogus', 0, 0),
    message('update', 'NaN', 1000), message('update', 361, 1000), message('update', 0, -1),
    message('finish', 0, 1000, 2), message('update', 0, 1000) + ',extra']) assert.equal(g.parse(invalid), null);
assert.equal(g.progress(0, 60), .2);
assert.equal(g.progress(1, -90), .7);
assert.equal(g.progress(.5, -360), 0);
assert.equal(g.progress(.5, 360), 1);
assert.equal(g.destination(.4, .005, 300, false, false), 0); // held, stale momentum
assert.equal(g.destination(.15, .004, 10, false, false), 1); // opening flick
assert.equal(g.destination(.85, -.004, 10, false, true), 0); // closing flick
assert.equal(g.destination(.8, .01, 0, true, false), 0); // cancelled opening
assert.equal(g.destination(.2, -.01, 0, true, true), 1); // cancelled closing
'''
        subprocess.run(['node', '-e', script, str(ROOT / 'shell/logic/OverviewGesture.js')], check=True)

    @unittest.skipUnless(shutil.which('lua'), 'Lua is needed to check compositor callbacks')
    def test_native_callbacks_accumulate_reverse_clamp_and_finish_once(self):
        script = r'''
local sent = {}
hl = { dsp = {event = function(s) return s end}, dispatch = function(s) sent[#sent + 1] = s end }
local factory = dofile(arg[1])
local up = factory("up")
up.update({delta={y=-10},time_ms=1})
assert(#sent == 0)
up.start({delta={y=-800},time_ms=10})
up.update({delta={y=60},time_ms=20})
up.finish({time_ms=30,cancelled=true})
up.finish({time_ms=40})
assert(#sent == 3)
assert(sent[1]:match(',start,1,360%.000,10,0$'))
assert(sent[2]:match(',update,1,300%.000,20,0$'))
assert(sent[3]:match(',finish,1,300%.000,30,1$'))
local first = sent[1]:match('v1,([^,]+),')
up.start({delta={y=0},time_ms=50})
assert(first ~= sent[4]:match('v1,([^,]+),'))
local down = factory("down")
down.start({delta={y=90},time_ms=60})
assert(sent[5]:match(',start,%-1,%-90%.000,60,0$'))
'''
        subprocess.run(['lua', '-', str(ROOT / 'dotfiles/hypr/.config/hypr/hyprland-overview.lua')], input=script, text=True, check=True)
