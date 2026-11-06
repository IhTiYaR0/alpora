.pragma library

function _tr(k, fallback) { return (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr(k) : fallback; }

// Screen-normalized positions; speed and clearance are measured in logical pixels.
function create(seed) {
    return {seed:(seed || 17)>>>0,mode:"rail",age:0,duration:10,x:0,y:0,direction:1,bank:0,
        fromX:0,fromY:0,controlX:0,controlY:0,targetX:0,targetY:0,trips:0,
        support:"",lastSupport:"",anchor:.5,walkTo:.5,walking:false};
}
function random(s) {s.seed=(Math.imul(s.seed,1664525)+1013904223)>>>0;return s.seed/4294967296;}
function clamp(v) {return Math.max(0,Math.min(1,v));}
function surfaces(ctx) {return ctx.surfaces || [{id:"floor",kind:"floor",minX:.12,maxX:.88,y:1}];}
function find(s,ctx) {return surfaces(ctx).find(p=>p.id===s.support);}
function origin(p) {return p.originX===undefined?p.minX:p.originX;}
function width(p) {return p.width===undefined?p.maxX-p.minX:p.width;}
function anchorFor(p,x) {return (x-origin(p))/Math.max(.00001,width(p));}
function point(s,ctx) {
    if(s.support==="home")return {x:ctx.homeX,y:ctx.homeY};
    const p=find(s,ctx);
    if(!p)return null;
    const x=origin(p)+width(p)*s.anchor;
    return x>=p.minX-.00001 && x<=p.maxX+.00001?{x:x,y:p.y}:null;
}
function leg(s,mode,ctx,x,y) {
    s.mode=mode;s.age=0;s.fromX=s.x;s.fromY=s.y;s.targetX=clamp(x);s.targetY=clamp(y);s.walking=false;
    const w=ctx.width || 1800,h=ctx.height || 1000;
    s.duration=mode==="land"?.75:Math.max(1.3,Math.min(8,Math.hypot((x-s.x)*w,(y-s.y)*h)/190));
    s.controlX=(s.x+s.targetX)/2;
    s.controlY=mode==="land"?(s.y+s.targetY)/2:Math.max(0,Math.min(s.y,s.targetY)-70/h);
}
function visit(s,ctx) {
    let choices=surfaces(ctx).filter(p=>p.id!==s.support && p.id!==s.lastSupport);
    if(!choices.length)choices=surfaces(ctx).filter(p=>p.id!==s.support);
    if(!choices.length) {s.support="home";const p=point(s,ctx);leg(s,"return",ctx,p.x,p.y);return;}
    // Widgets and windows are destinations; the floor is a less frequent stop.
    const raised=choices.filter(p=>p.kind!=="floor");
    if(raised.length && random(s)<.85)choices=raised;
    s.lastSupport=s.support;s.support=choices[Math.floor(random(s)*choices.length)].id;
    const chosen=find(s,ctx);
    s.anchor=anchorFor(chosen,chosen.minX+(chosen.maxX-chosen.minX)*(.2+random(s)*.6));
    const p=point(s,ctx);leg(s,"fly",ctx,p.x,Math.max(0,p.y-22/(ctx.height || 1000)));
}
function launch(previous,ctx) {
    const s=Object.assign({},previous);
    if(s.mode!=="rail" || !ctx.enabled || ctx.lowBattery)return s;
    s.x=ctx.homeX;s.y=ctx.homeY;s.trips++;visit(s,ctx);return s;
}
function recall(previous,ctx) {
    const s=Object.assign({},previous);
    if(s.mode!=="rail" && s.support!=="home") {
        s.support="home";leg(s,"return",ctx,ctx.homeX,Math.max(0,ctx.homeY-22/(ctx.height || 1000)));
    }
    return s;
}
function resumeAt(previous,ctx,x,y) {
    let s=Object.assign({},previous);s.x=clamp(x);s.y=clamp(y);s.bank=0;s.support="";s.mode="fly";
    if(!ctx.enabled || ctx.lowBattery)return recall(s,ctx);
    visit(s,ctx);return s;
}
function perchAt(previous,ctx,id,x) {
    const s=Object.assign({},previous),p=surfaces(ctx).find(v=>v.id===id);
    if(!p)return resumeAt(s,ctx,x,s.y);
    s.support=id;s.anchor=anchorFor(p,Math.max(p.minX,Math.min(p.maxX,x)));
    s.walkTo=s.anchor;s.x=origin(p)+width(p)*s.anchor;s.y=p.y;s.mode=p.kind==="floor"?"floor":"perch";
    s.age=0;s.duration=7+random(s)*5;s.walking=false;s.bank=0;return s;
}
function step(previous,elapsed,ctx) {
    let s=Object.assign({},previous),dt=Math.max(0,Math.min(.1,elapsed));
    const w=ctx.width || 1800,h=ctx.height || 1000;
    if(s.mode==="rail") {
        s.x=ctx.homeX;s.y=ctx.homeY;s.bank=0;s.age+=dt;
        return s.age>=s.duration?launch(s,ctx):s;
    }
    if((!ctx.enabled || ctx.lowBattery) && s.support!=="home")s=recall(s,ctx);
    let p=point(s,ctx);
    if(!p) {s.support="";visit(s,ctx);p=point(s,ctx);}
    if(s.mode==="perch" || s.mode==="floor") {
        // Keep the same position on a moved/resized window. Walking changes the
        // anchor only; it can never carry the feet past a legal support interval.
        s.age+=dt;s.walking=false;
        const support=find(s,ctx),span=(support.maxX-support.minX)*w;
        if(s.age>.85 && s.age< s.duration-1 && span>20) {
            const left=anchorFor(support,support.minX),right=anchorFor(support,support.maxX);
            if(s.walkTo===s.anchor)s.walkTo=s.anchor>(left+right)/2?left+(right-left)*.15:left+(right-left)*.85;
            s.walkTo=Math.max(left,Math.min(right,s.walkTo));
            const delta=s.walkTo-s.anchor,move=Math.min(Math.abs(delta),26*dt/Math.max(.00001,width(support)*w));
            s.anchor+=Math.sign(delta)*move;s.walking=move>0;
            if(move>0)s.direction=Math.sign(delta);
            if(Math.abs(s.walkTo-s.anchor)<.00001)s.walkTo=s.anchor;
        }
        p=point(s,ctx);s.x=p.x;s.y=p.y;s.bank=0;
        if(s.age>=s.duration) {s.trips++;if(s.trips%4===0)s=recall(s,ctx);else visit(s,ctx);}
        return s;
    }
    const targetY=s.mode==="land"?p.y:Math.max(0,p.y-22/h);
    if(Math.hypot((p.x-s.targetX)*w,(targetY-s.targetY)*h)>2)
        leg(s,s.mode,ctx,p.x,targetY);
    s.age=Math.min(s.duration,s.age+dt);
    // Minimum-jerk timing has zero velocity and acceleration at both endpoints.
    const t=s.age/s.duration,e=t*t*t*(10+t*(-15+6*t)),one=1-e,oldX=s.x;
    s.x=clamp(one*one*s.fromX+2*one*e*s.controlX+e*e*s.targetX);
    s.y=clamp(one*one*s.fromY+2*one*e*s.controlY+e*e*s.targetY);
    const vx=dt>0?(s.x-oldX)*w/dt:0;
    if(Math.abs(vx)>1)s.direction=Math.sign(vx);
    s.bank+=(Math.max(-8,Math.min(8,vx/32))-s.bank)*(1-Math.exp(-8*dt));
    if(s.age>=s.duration) {
        if(s.mode!=="land")leg(s,"land",ctx,p.x,p.y);
        else if(s.support==="home") {s.mode="rail";s.age=0;s.duration=(ctx.lively?9:25)+random(s)*10;s.bank=0;s.support="";}
        else s=perchAt(s,ctx,s.support,s.x);
    }
    return s;
}
function label(mode) {return ({fly:_tr("companion.travel.fly","Летит к поверхности"),perch:_tr("companion.travel.perch","Гуляет по краю"),floor:_tr("companion.travel.floor","Гуляет по рабочему столу"),return:_tr("companion.travel.return","Возвращается"),land:_tr("companion.travel.land","Приземляется")})[mode]||_tr("companion.travel.panel","На панели");}
