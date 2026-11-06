pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var values: []
    property var draft: []
    property var actions: []
    property var globals: []
    property var external: []
    property var response: null
    property bool loaded: false
    property bool editingForm: false
    property string error: ""
    property string message: ""
    readonly property bool busy: reader.running || writer.running
    readonly property bool dirty: JSON.stringify(values)!==JSON.stringify(draft)
    function copy(value: var): var {return JSON.parse(JSON.stringify(value));}
    function refresh(): void {if (!busy && !dirty) {error="";reader.running=true;}}
    function cancel(): void {if (!busy) {draft=copy(values);error="";message="";}}
    function edit(item: var): void {
        if (busy)return;
        const next=copy(draft),index=next.findIndex(r=>r.id===item.id);
        if(index<0)next.push(copy(item));else next[index]=copy(item);
        draft=next;error="";message="";
    }
    function remove(id: string): void {
        if(busy)return;
        const item=draft.find(r=>r.id===id);
        if(!item)return;
        if(item.source)edit(Object.assign({},item,{enabled:false}));
        else draft=draft.filter(r=>r.id!==id);
    }
    function apply(): void {
        if(busy || !dirty)return;
        error="";message="";response=null;
        writer.command=[Session.controller,"shortcuts","apply",JSON.stringify({values:draft,expected:values})];
        writer.running=true;
    }
    Process {
        id: reader
        command:[Session.controller,"shortcuts","get"]
        stdout:StdioCollector {onStreamFinished: {
            try {
                const data=JSON.parse(text);
                if(![data.values,data.actions,data.globals,data.external].every(v=>Array.isArray(v)))throw new Error("Invalid shortcut response");
                root.values=data.values;root.draft=root.copy(data.values);root.actions=data.actions;
                root.globals=data.globals;root.external=data.external;root.loaded=true;
            }catch(_){root.error=I18n.tr("shortcuts.error_read");}
        }}
        stderr:StdioCollector {onStreamFinished:if(text.trim())root.error=text.trim().replace(/^poly-shell: /,"")}
    }
    Process {
        id: writer
        stdout:StdioCollector {onStreamFinished:{try{root.response=JSON.parse(text);}catch(_){}}}
        stderr:StdioCollector {onStreamFinished:if(text.trim())root.error=text.trim().replace(/^poly-shell: /,"")}
        onExited:exitCode=> {
            if(exitCode===0 && root.response && root.response.saved && Array.isArray(root.response.values)) {
                root.values=root.copy(root.response.values);root.draft=root.copy(root.values);
                root.message=I18n.tr("shortcuts.saved");
            }else if(!root.error)root.error=I18n.tr("shortcuts.error_apply");
        }
    }
}
