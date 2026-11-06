"""Long-running companion behavior stays bounded and follows real state."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('node'), 'Companion simulation requires Node')
class CompanionBehaviorTests(unittest.TestCase):
    def evaluate(self, code):
        source = (ROOT / 'shell/logic/CompanionLogic.js').read_text(encoding='utf-8').replace('.pragma library', '')
        return json.loads(subprocess.check_output(['node', '-e', source + '\n' + code], text=True, encoding='utf-8'))

    def test_long_sessions_remain_inside_rail_and_do_not_repeat_actions(self):
        result = self.evaluate('''
            let min=1,max=0,invalid=0,repeat=0,seen={};
            for(const lively of [true,false]) for(const music of [true,false])
                for(const charging of [true,false]) for(const lowBattery of [true,false]) {
                    let s=create(729);
                    for(let i=0;i<72000;i++) {
                        const old=s; s=step(s,0.05,{lively,music,charging,lowBattery});
                        min=Math.min(min,s.position);max=Math.max(max,s.position);
                        if(!Number.isFinite(s.position)||s.position<0||s.position>1||s.age<0)invalid++;
                        if(s.actions!==old.actions&&s.activity===old.activity)repeat++;
                        if((s.activity==='dance'&&!music)||(s.activity==='charge'&&!charging))invalid++;
                        seen[s.activity]=true;
                    }
                }
            console.log(JSON.stringify({min,max,invalid,repeat,seen}));
        ''')
        self.assertEqual(result['invalid'], 0)
        self.assertEqual(result['repeat'], 0)
        self.assertGreater(result['max'] - result['min'], .8)
        self.assertEqual(len(result['seen']), 11)

    def test_audio_and_power_reactions_end_when_real_state_ends(self):
        result = self.evaluate('''
            const ctx={lively:true,music:false,charging:false,lowBattery:false};
            const dancing=step(react(create(7),'dance'),.05,ctx);
            const charging=step(react(create(8),'charge'),.05,ctx);
            console.log(JSON.stringify([dancing.activity,charging.activity]));
        ''')
        self.assertNotEqual(result[0], 'dance')
        self.assertNotEqual(result[1], 'charge')

    def test_slow_or_negative_ticks_cannot_teleport_character(self):
        result = self.evaluate('''
            let s=create(16);s.activity='walk';s.destination=1;s.duration=100;
            const a=step(s,3600,{lively:true});
            const b=step(s,-10,{lively:true});
            console.log(JSON.stringify([a.position-s.position,b.position-s.position]));
        ''')
        self.assertLessEqual(result[0], .010001)
        self.assertEqual(result[1], 0)


@unittest.skipUnless(shutil.which('node'), 'Flight simulation requires Node')
class CompanionTravelTests(unittest.TestCase):
    def evaluate(self, code):
        source = (ROOT / 'shell/logic/CompanionTravel.js').read_text(encoding='utf-8').replace('.pragma library', '')
        return json.loads(subprocess.check_output(['node', '-e', source + '\n' + code], text=True, encoding='utf-8'))

    def test_routes_complete_repeatedly_without_escaping_screen_or_teleporting(self):
        result = self.evaluate(''' 
            const ctx={enabled:true,lively:true,lowBattery:false,homeX:.31,homeY:.007};
            let s=create(91),bad=0,jump=0,modes={};
            s=step(s,0,ctx);
            for(let i=0;i<100000;i++) {
                const old=s;s=step(s,.033,ctx);modes[s.mode]=true;
                if(!Number.isFinite(s.x)||!Number.isFinite(s.y)||s.x<0||s.x>1||s.y<0||s.y>1)bad++;
                jump=Math.max(jump,Math.hypot(s.x-old.x,s.y-old.y));
            }
            console.log(JSON.stringify({bad,jump,modes,trips:s.trips}));
        ''')
        self.assertEqual(result['bad'], 0)
        self.assertLess(result['jump'], .03)
        self.assertEqual(set(result['modes']), {'rail', 'fly', 'land', 'floor', 'return'})
        self.assertGreater(result['trips'], 40)

    def test_disabling_flight_or_low_battery_returns_to_current_home(self):
        result = self.evaluate('''
            let results=[];
            for(const disabled of [true,false]) {
                const ctx={enabled:true,lively:true,lowBattery:false,homeX:.24,homeY:.01};
                let s=launch(create(5),ctx);
                for(let i=0;i<200;i++)s=step(s,.05,ctx);
                if(disabled)ctx.enabled=false;else ctx.lowBattery=true;
                ctx.homeX=.63;
                let phases={},jump=0;
                for(let i=0;i<600;i++) {const old=s;s=step(s,.05,ctx);phases[s.mode]=true;jump=Math.max(jump,Math.hypot(s.x-old.x,s.y-old.y));}
                results.push({mode:s.mode,x:s.x,y:s.y,phases,jump});
            }
            console.log(JSON.stringify(results));
        ''')
        for result in result:
            self.assertEqual(result['mode'], 'rail')
            self.assertAlmostEqual(result['x'], .63)
            self.assertAlmostEqual(result['y'], .01)
            self.assertNotIn('floor', result['phases'])
            self.assertLess(result['jump'], .04)

    def test_disabled_and_low_battery_cannot_launch_even_on_click(self):
        result = self.evaluate('''
            const home={homeX:.3,homeY:.01,lively:true};
            console.log(JSON.stringify([
                launch(create(3),Object.assign({},home,{enabled:false})).mode,
                launch(create(3),Object.assign({},home,{enabled:true,lowBattery:true})).mode
            ]));
        ''')
        self.assertEqual(result, ['rail', 'rail'])

    def test_standing_follows_window_and_missing_surface_departs_continuously(self):
        result = self.evaluate('''
            const ctx={enabled:true,lively:true,homeX:.3,homeY:.01,width:1800,height:1000,
                surfaces:[{id:'window',kind:'window',minX:.2,maxX:.7,y:.4,originX:.1,width:.7},
                    {id:'widget',kind:'widget',minX:.6,maxX:.8,y:.7}]};
            let s=perchAt(create(4),ctx,'window',.4);
            ctx.surfaces[0].minX+=.1;ctx.surfaces[0].maxX+=.1;ctx.surfaces[0].originX+=.1;ctx.surfaces[0].y+=.05;
            s=step(s,.016,ctx);const attached={x:s.x,y:s.y,mode:s.mode};
            let outside=0;
            for(let i=0;i<180;i++) {s=step(s,.016,ctx);if(s.x<.3||s.x>.8||s.y!==.45)outside++;}
            const old=s;ctx.surfaces.shift();s=step(s,.016,ctx);
            console.log(JSON.stringify({attached,outside,mode:s.mode,delta:Math.hypot(s.x-old.x,s.y-old.y)}));
        ''')
        self.assertAlmostEqual(result['attached']['x'], .5)
        self.assertAlmostEqual(result['attached']['y'], .45)
        self.assertEqual(result['attached']['mode'], 'perch')
        self.assertEqual(result['outside'], 0)
        self.assertEqual(result['mode'], 'fly')
        self.assertLess(result['delta'], .001)

    def test_occlusion_cannot_teleport_grounded_robot_to_another_visible_fragment(self):
        result = self.evaluate('''
            const ctx={enabled:true,homeX:.3,homeY:.01,width:1800,height:1000,
                surfaces:[{id:'widget:0',kind:'widget',minX:.1,maxX:.8,y:.5,originX:.05,width:.8}]};
            let s=perchAt(create(4),ctx,'widget:0',.3),old=s;
            ctx.surfaces[0].minX=.6;
            s=step(s,.016,ctx);
            const disabled=Object.assign({},ctx,{enabled:false});
            const rescued=resumeAt(create(7),disabled,.6,.7);
            console.log(JSON.stringify({mode:s.mode,jump:Math.hypot(s.x-old.x,s.y-old.y),rescued}));
        ''')
        self.assertEqual(result['mode'], 'fly')
        self.assertLess(result['jump'], .001)
        self.assertEqual(result['rescued']['mode'], 'return')
        self.assertEqual(result['rescued']['x'], .6)
        self.assertEqual(result['rescued']['y'], .7)

    def test_widget_and_window_visits_land_exactly_and_retarget_without_snapping(self):
        result = self.evaluate('''
            const ctx={enabled:true,lively:true,homeX:.3,homeY:.01,width:1800,height:1000,
                surfaces:[{id:'window',kind:'window',minX:.2,maxX:.7,y:.4},
                    {id:'widget',kind:'widget',minX:.6,maxX:.8,y:.7}]};
            let s=launch(create(7),ctx),landings={},bad=0,jump=0;
            for(let i=0;i<30000;i++) {
                const old=s;s=step(s,.016,ctx);jump=Math.max(jump,Math.hypot(s.x-old.x,s.y-old.y));
                if(s.mode==='perch') {
                    const p=ctx.surfaces.find(p=>p.id===s.support);landings[p.id]=true;
                    if(s.y!==p.y||s.x<p.minX||s.x>p.maxX)bad++;
                }
                if(i%500===0)ctx.surfaces[0].y=ctx.surfaces[0].y===.4?.5:.4;
            }
            console.log(JSON.stringify({landings,bad,jump}));
        ''')
        self.assertEqual(result['bad'], 0)
        self.assertEqual(set(result['landings']), {'window', 'widget'})
        # A support moved by .1 carries its grounded passenger by the same amount.
        self.assertLessEqual(result['jump'], .101)


@unittest.skipUnless(shutil.which('node'), 'Throw simulation requires Node')
class CompanionThrowTests(unittest.TestCase):
    def evaluate(self, code):
        source = (ROOT / 'shell/logic/CompanionThrow.js').read_text(encoding='utf-8').replace('.pragma library', '').replace('.import \"CompanionSurfaces.js\" as Surfaces', '')
        support = (ROOT / 'shell/logic/CompanionSurfaces.js').read_text(encoding='utf-8').replace('.pragma library', '')
        source = 'const Surfaces=(()=>{' + support + ';return {crossing};})();\n' + source
        return json.loads(subprocess.check_output(['node', '-e', source + '\n' + code], text=True, encoding='utf-8'))

    def test_fast_release_keeps_momentum_then_brakes_recovers_and_folds_arms(self):
        result = self.evaluate('''
            const b={minX:8,maxX:1800,maxY:1000};
            let s=grab(400,200,1000);s=move(s,470,170,1050,b);s=release(s,1050,false);
            const vx=s.vx,vy=s.vy,strong=s.strong,seen={};let bad=0;
            for(let i=0;i<500;i++) {s=step(s,.016,b);seen[s.mode]=true;if(s.x<8||s.x>1800||s.y<0||s.y>1000||!Number.isFinite(s.x))bad++;}
            console.log(JSON.stringify({vx,vy,strong,seen,bad,mode:s.mode}));
        ''')
        self.assertGreater(result['vx'], 700)
        self.assertLess(result['vy'], 0)
        self.assertTrue(result['strong'])
        self.assertEqual(result['bad'], 0)
        self.assertEqual(result['mode'], 'done')
        self.assertEqual(set(result['seen']), {'fall', 'brake', 'recover', 'shake', 'annoyed', 'done'})

    def test_hold_before_release_dissipates_throw_velocity(self):
        result = self.evaluate('''
            const b={maxX:1800,maxY:1000};let s=move(grab(200,200,1000),300,220,1040,b);
            s=release(s,1740,false);console.log(JSON.stringify({speed:Math.hypot(s.vx,s.vy),strong:s.strong}));
        ''')
        self.assertLess(result['speed'], 5)
        self.assertFalse(result['strong'])

    def test_edges_cancellation_and_stalls_cannot_escape_or_get_stuck(self):
        result = self.evaluate('''
            let bad=0,unfinished=0;
            for(const size of [[320,140],[1920,1080],[800,1920]])
             for(const vx of [-1300,0,1300])for(const vy of [-1300,0,1300])for(const cancelled of [false,true]) {
                const b={minX:8,maxX:size[0]-70,maxY:size[1]-62};
                let s=grab(b.maxX/2,b.maxY/2,1000);s.vx=vx;s.vy=vy;s=release(s,1000,cancelled);
                for(let i=0;i<700;i++) {s=step(s,i%19===0?4:.016,b);if(!Number.isFinite(s.x)||s.x<8||s.x>b.maxX||s.y<0||s.y>b.maxY||Math.abs(s.angle)>18.01)bad++;}
                if(s.mode!=='done')unfinished++;
             }
            console.log(JSON.stringify({bad,unfinished}));
        ''')
        self.assertEqual(result, {'bad': 0, 'unfinished': 0})

    def test_drops_land_on_first_crossed_edge_and_misses_continue_to_rescue(self):
        result = self.evaluate('''
            const b={minX:8,maxX:1800,maxY:1000,surfaces:[
                {id:'lower',minX:200,maxX:500,y:350},{id:'upper',minX:200,maxX:500,y:240}]};
            let s=release(grab(300,200,1000),1300,false),miss=release(grab(600,200,1000),1300,false);
            for(let i=0;i<240;i++){s=step(s,.016,b);miss=step(miss,.016,b);}
            console.log(JSON.stringify({mode:s.mode,id:s.support,y:s.y,vx:s.vx,miss:miss.mode}));
        ''')
        self.assertEqual(result, {'mode':'landed','id':'upper','y':240,'vx':0,'miss':'done'})


@unittest.skipUnless(shutil.which('node'), 'Surface simulation requires Node')
class CompanionSurfaceTests(unittest.TestCase):
    def evaluate(self, code):
        source = (ROOT / 'shell/logic/CompanionSurfaces.js').read_text(encoding='utf-8').replace('.pragma library', '')
        return json.loads(subprocess.check_output(['node', '-e', source + '\n' + code], text=True, encoding='utf-8'))

    def test_occlusion_workspace_monitor_and_bar_clearance(self):
        result = self.evaluate('''
            const screen={x:1920,y:0,width:1920,height:1080},foot={width:70,height:54,extent:45,feet:48};
            const widgets=[{id:'widget',kind:'widget',x:20,y:200,width:460,height:200,radius:16}];
            const client=(id,x,y,w,h,ws)=>({address:id,mapped:true,hidden:false,at:[1920+x,y],size:[w,h],workspace:{id:ws}});
            const covered=build(widgets,[client('cover',0,150,600,400,2)],screen,2,foot,{left:254,right:726,bottom:50});
            const otherWorkspace=build(widgets,[client('other',0,150,600,400,1)],screen,2,foot,{left:254,right:726,bottom:50});
            const tiled=build([], [client('tiled',14,74,1892,992,2)],screen,2,foot,{left:254,right:726,bottom:50});
            console.log(JSON.stringify({covered,otherWorkspace,tiled}));
        ''')
        self.assertFalse(any(p['kind'] == 'widget' for p in result['covered']))
        self.assertTrue(any(p['kind'] == 'widget' for p in result['otherWorkspace']))
        top = next(p for p in result['tiled'] if p['kind'] == 'window')
        self.assertEqual(top['y'], 26)
        self.assertGreaterEqual(top['minX'], 254)
        self.assertLessEqual(top['maxX'], 656)

    def test_partial_occlusion_splits_edge_without_support_under_window(self):
        result = self.evaluate('''
            const values=build([{id:'widget',kind:'widget',x:100,y:400,width:800,height:200,radius:12}],
                [{address:'cover',mapped:true,hidden:false,at:[400,200],size:[100,300],workspace:{id:1}}],
                {x:0,y:0,width:1920,height:1080},1,{width:70,height:54,extent:45,feet:48},{left:254,right:726,bottom:50});
            console.log(JSON.stringify(values.filter(p=>p.kind==='widget')));
        ''')
        self.assertEqual(len(result), 2)
        self.assertLessEqual(result[0]['maxX'], 328)
        self.assertGreaterEqual(result[1]['minX'], 502)


if __name__ == '__main__':
    unittest.main()
