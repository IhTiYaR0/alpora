.pragma library
.import "CompanionSurfaces.js" as Surfaces

// Pixel-space toy physics. It never reads the pointer or compositor itself.
// Input sampling is event-driven, and simulation runs only on the UI clock.
function create() { return {mode:"idle",x:0,y:0,vx:0,vy:0,age:0,angle:0,strong:false,lastTime:0,fromX:0,fromY:0,targetY:0}; }
function clamp(v,lo,hi) { return Math.max(lo,Math.min(hi,v)); }
function grab(x,y,time) {
    const s=create();s.mode="grabbed";s.x=x;s.y=y;s.lastTime=time;return s;
}
function move(previous,x,y,time,bounds) {
    const s=Object.assign({},previous);
    if(s.mode!=="grabbed") return s;
    x=clamp(x,bounds.minX || 0,bounds.maxX);y=clamp(y,0,bounds.maxY);
    const dt=clamp((time-s.lastTime)/1000,0.008,0.12);
    // Configuration/zero-motion events must not replace the last real sample.
    if(Math.hypot(x-s.x,y-s.y)<0.2) return s;
    s.vx=clamp(s.vx*0.35+(x-s.x)/dt*0.65,-1300,1300);
    s.vy=clamp(s.vy*0.35+(y-s.y)/dt*0.65,-1300,1300);
    s.x=x;s.y=y;s.lastTime=time;
    s.angle=clamp(-s.vx/45,-18,18);
    return s;
}
function release(previous,time,cancelled) {
    const s=Object.assign({},previous);
    if(s.mode!=="grabbed") return s;
    const decay=Math.exp(-Math.max(0,time-s.lastTime-60)/110);
    s.vx=cancelled?0:s.vx*decay;s.vy=cancelled?0:s.vy*decay;
    s.strong=Math.hypot(s.vx,s.vy)>650;
    s.mode=cancelled?"brake":"fall";s.age=0;
    return s;
}
function step(previous,elapsed,bounds) {
    const s=Object.assign({},previous),dt=clamp(elapsed,0,0.05);
    if(s.mode==="idle" || s.mode==="done" || s.mode==="landed")return s;
    s.age+=dt;
    if(s.mode==="grabbed") {
        s.angle=clamp(s.angle*0.96+Math.sin(s.age*7)*0.3,-18,18);
        return s;
    }
    if(s.mode==="fall" || s.mode==="brake") {
        const steps=Math.max(1,Math.ceil(dt/0.008)),h=dt/steps;
        for(let i=0;i<steps;i++) {
            if(s.mode==="fall")s.vy+=1300*h;
            else {s.vx*=Math.exp(-5*h);s.vy+=(-s.vy*7-240)*h;}
            const oldX=s.x,oldY=s.y;
            s.x+=s.vx*h;s.y+=s.vy*h;
            const contact=Surfaces.crossing(bounds.surfaces,oldX,oldY,s.x,s.y);
            if(contact) {
                s.mode="landed";s.support=contact.id;s.y=contact.y;
                s.x=clamp(s.x,contact.minX,contact.maxX);s.vx=0;s.vy=0;s.angle=0;
                return s;
            }
            if(s.x<(bounds.minX || 0) || s.x>bounds.maxX){s.x=clamp(s.x,bounds.minX || 0,bounds.maxX);s.vx*=-0.25;}
            if(s.y<0){s.y=0;s.vy=Math.abs(s.vy)*0.25;}
            if(s.y>bounds.maxY){s.y=bounds.maxY;s.vy=-Math.abs(s.vy)*0.12;}
        }
        if(s.mode==="fall") {
            s.angle=clamp(s.angle+s.vx*dt*0.018,-18,18);
            if(s.age>=0.42 || (s.vy>0 && bounds.maxY-s.y<75)) {s.mode="brake";s.age=0;}
        } else {
            s.angle*=Math.exp(-7*dt);
            if(s.age>=0.85) {
                s.mode="recover";s.age=0;s.fromX=s.x;s.fromY=s.y;
                s.targetY=clamp(s.y-48,Math.min(70,bounds.maxY),bounds.maxY);
                s.vx=0;s.vy=0;
            }
        }
    } else if(s.mode==="recover") {
        const p=clamp(s.age/0.7,0,1),e=p*p*(3-2*p);
        s.x=s.fromX;s.y=s.fromY+(s.targetY-s.fromY)*e;s.angle*=Math.exp(-8*dt);
        if(p===1){s.mode=s.strong?"shake":"done";s.age=0;s.angle=0;}
    } else if(s.mode==="shake") {
        s.angle=Math.sin(s.age*35)*5*(1-clamp(s.age/0.65,0,1));
        if(s.age>=0.65){s.mode="annoyed";s.age=0;s.angle=0;}
    } else if(s.mode==="annoyed" && s.age>=1.6) {s.mode="done";s.age=0;}
    s.x=clamp(s.x,bounds.minX || 0,bounds.maxX);s.y=clamp(s.y,0,bounds.maxY);
    return s;
}
