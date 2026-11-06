.pragma library

// Legal positions of the small robot window, not just points on a rectangle.
// Conservative occlusion keeps a pet off a widget hidden behind an application.
function build(widgets, clients, screen, workspace, footprint, rail) {
    const windows=clients.filter(c=>c.mapped && !c.hidden && c.at && c.size &&
        (c.pinned || (c.workspace && c.workspace.id===workspace)))
        .map(c=>({id:"window:"+c.address,kind:"window",x:c.at[0]-screen.x,y:c.at[1]-screen.y,
            width:c.size[0],height:c.size[1],radius:12,z:(c.floating?10000:0)-(c.focusHistoryID || 0)}));
    const result=[];
    for(const box of widgets.concat(windows)) {
        const y=box.y-footprint.feet;
        if(y<0 || y>screen.height-footprint.height)continue;
        let lo=Math.max(8,box.x+box.radius-12),hi=Math.min(screen.width-footprint.width-8,box.x+box.width-box.radius-12-footprint.extent);
        // Above a tiled window, only the unused bar lane is safe for the body.
        if(y<rail.bottom+4) {lo=Math.max(lo,rail.left);hi=Math.min(hi,rail.right-footprint.width);}
        let spans=hi>=lo?[[lo,hi]]:[];
        for(const other of windows) {
            if(other.id===box.id || (box.kind==="window" && other.z<box.z) || other.y>=box.y+2 || other.y+other.height<=y+2)continue;
            const left=other.x-footprint.width-2,right=other.x+other.width+2;
            const next=[];
            for(const span of spans) {
                if(span[1]<left || span[0]>right)next.push(span);
                else {
                    if(left-span[0]>=12)next.push([span[0],Math.min(span[1],left)]);
                    if(span[1]-right>=12)next.push([Math.max(span[0],right),span[1]]);
                }
            }
            spans=next;
        }
        spans.forEach((span,index)=>result.push({id:box.id+":"+index,kind:box.kind,minX:span[0],maxX:span[1],y:y,originX:box.x,width:box.width}));
    }
    result.push({id:"floor",kind:"floor",minX:8,maxX:screen.width-footprint.width-8,y:screen.height-10-footprint.feet});
    return result;
}
function crossing(surfaces,oldX,oldY,x,y) {
    if(y<oldY)return null;
    let hit=null;
    for(const surface of surfaces || []) {
        if(oldY>surface.y+1 || y<surface.y)continue;
        const t=y===oldY?1:(surface.y-oldY)/(y-oldY);
        const atX=oldX+(x-oldX)*Math.max(0,Math.min(1,t));
        if(atX>=surface.minX && atX<=surface.maxX && (!hit || surface.y<hit.y))hit=surface;
    }
    return hit;
}
