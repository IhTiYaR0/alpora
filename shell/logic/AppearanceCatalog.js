.pragma library

function _tr(k, fallback) { return (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr(k) : fallback; }
// Shared UI metadata; backend validates every saved value.
var defaults = {"windowRadius": 16, "barRadius": 20, "panelRadius": 20, "barOpacity": 75, "panelOpacity": 75, "launcherOpacity": 75, "activeOpacity": 100, "inactiveOpacity": 100, "blurEnabled": true, "blurSize": 3, "blurPasses": 1, "launcherRadius": 20, "widgetRadius": 16, "notificationRadius": 13, "widgetOpacity": 75, "notificationOpacity": 75, "panelPadding": 16, "launcherPadding": 18, "notificationPadding": 12, "barBorder": 1, "panelBorder": 1, "launcherBorder": 1, "widgetBorder": 1, "notificationBorder": 1, "barShadow": 20, "panelShadow": 20, "launcherShadow": 20, "widgetShadow": 0, "notificationShadow": 0, "panelOpenMs": 320, "panelCloseMs": 200, "launcherOpenMs": 320, "launcherCloseMs": 200, "widgetAnimations": true, "widgetFadeMs": 420, "barHeight": 40, "barMargin": 20, "barTop": 12, "barLeft": 20, "barRight": 20, "barBottom": 8, "windowGap": 5, "windowMargin": 12};

var elements = [
 {id:"window",title:_tr("appearance.elem.window.title","Окна"),icon:"window",description:_tr("appearance.elem.window.desc","Отступы управляют раскладкой окон. Непрозрачность затрагивает всё содержимое, включая текст.")},
 {id:"bar",title:_tr("appearance.elem.bar.title","Бар"),icon:"panel",description:_tr("appearance.elem.bar.desc","Верхняя панель: материал, форма и расположение на экране.")},
 {id:"panel",title:_tr("appearance.elem.panel.title","Меню"),icon:"settings",description:_tr("appearance.elem.panel.desc","Быстрые настройки, календарь и всплывающие панели.")},
 {id:"widget",title:_tr("appearance.elem.widget.title","Виджеты"),icon:"devices",description:_tr("appearance.elem.widget.desc","Карточки часов, погоды и музыки на рабочем столе.")},
 {id:"launcher",title:_tr("appearance.elem.launcher.title","Лаунчер"),icon:"search",description:_tr("appearance.elem.launcher.desc","Поиск и список приложений, включая компактную панель.")},
 {id:"notification",title:_tr("appearance.elem.notification.title","Уведомления"),icon:"bell",description:_tr("appearance.elem.notification.desc","Карточки центра уведомлений и всплывающие сообщения Mako. Тень — только в центре.")}
];
function field(key,label,min,max,suffix) { return {key:key,label:label,min:min,max:max,suffix:suffix===undefined?" px":suffix}; }
function groups(element) {
 var material=[],geometry=[],result=[];
 if(element==="window") {
  material=[field("activeOpacity",_tr("appearance.field.active_opacity","Активное окно"),60,100," %"),field("inactiveOpacity",_tr("appearance.field.inactive_opacity","Неактивные окна"),60,100," %")];
  geometry=[field("windowRadius",_tr("appearance.field.window_radius","Скругление углов"),0,32),field("windowMargin",_tr("appearance.field.window_margin","От границ рабочей области"),0,128),field("windowGap",_tr("appearance.field.window_gap","Между окнами (на сторону)"),0,64)];
 } else {
  material=[field(element+"Opacity",_tr("appearance.field.bg_opacity","Непрозрачность фона"),element==="launcher"?75:element==="panel"?50:element==="notification"?20:40,100," %")];
  geometry=[field(element+"Radius",_tr("appearance.field.window_radius","Скругление углов"),0,element==="bar"?20:32)];
  if(["panel","launcher","notification"].indexOf(element)>=0) geometry.push(field(element+"Padding",_tr("appearance.field.inner_padding","Внутренние отступы"),element==="notification"?6:8,24));
  geometry.push(field(element+"Border",_tr("appearance.field.border_width","Толщина обводки"),0,3));
 }
 result.push({title:_tr("appearance.field.section_material","Материал"),icon:"transparency",fields:material});
 result.push({title:_tr("appearance.field.section_shape","Форма и отступы"),icon:"rounded",fields:geometry});
 if(element==="bar") result.push({title:_tr("appearance.field.section_placement","Расположение"),icon:"monitor",fields:[field("barHeight",_tr("appearance.field.bar_height","Высота панели"),32,80),field("barLeft",_tr("appearance.field.bar_left","Отступ слева"),0,128),field("barRight",_tr("appearance.field.bar_right","Отступ справа"),0,128),field("barTop",_tr("appearance.field.bar_top","Отступ сверху"),0,64),field("barBottom",_tr("appearance.field.bar_bottom","Свободное место под баром"),0,128)]});
 if(element!=="window") result.push({title:_tr("appearance.field.section_shadow","Тень"),icon:"focus",fields:[field(element+"Shadow",_tr("appearance.field.shadow_intensity","Интенсивность"),0,100," %")]});
 if(element==="panel"||element==="launcher") result.push({title:_tr("appearance.field.section_animations","Анимации"),icon:"music",fields:[field(element+"OpenMs",_tr("appearance.field.open_ms","Открытие"),0,800," ms"),field(element+"CloseMs",_tr("appearance.field.close_ms","Закрытие"),0,800," ms")]});
 if(element==="widget") result.push({title:_tr("appearance.field.section_animations","Анимации"),icon:"music",fields:[field("widgetFadeMs",_tr("appearance.field.widget_fade_ms","Появление карточек"),0,800," ms")]});
 return result;
}
function keys(element) {
 var result=[];groups(element).forEach(function(g){g.fields.forEach(function(f){result.push(f.key);});});
 if(element==="widget")result.push("widgetAnimations");
 return result;
}
function resolve(value,bar) {
 var out=Object.assign({},defaults,value||{});bar=bar||{};
 [["barHeight","height"],["barMargin","margin"],["barTop","top"]].forEach(function(pair){if(!value||value[pair[0]]===undefined)out[pair[0]]=bar[pair[1]]===undefined?defaults[pair[0]]:bar[pair[1]];});
 ["barLeft","barRight"].forEach(function(key){if(!value||value[key]===undefined)out[key]=out.barMargin;});
 if(value&&value.launcherRadius===undefined&&value.panelRadius!==undefined)out.launcherRadius=value.panelRadius;
 return out;
}
