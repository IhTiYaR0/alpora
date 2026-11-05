pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: (compact ? 8 : 12) * expansion
    property date month: new Date(ClockState.date.getFullYear(), ClockState.date.getMonth(), 1)
    property date selected: ClockState.date
    readonly property int firstOffset: (month.getDay() + 6) % 7
    readonly property var locale: I18n.qtLocale
    property bool compact: false
    property real expansion: 1
    readonly property int selectedWeek: Math.floor((selected.getDate() - 1 + firstOffset) / 7)
    property bool showFooter: true
    function shift(amount: int): void { month = new Date(month.getFullYear(), month.getMonth() + amount, 1); }
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 30 * root.expansion
        Layout.minimumHeight: 0; Layout.maximumHeight: 30 * root.expansion; clip: true
        BarButton { symbol: "chevron-left"; hint: I18n.tr("calendar.prev_month"); onClicked: root.shift(-1) }
        Button {
            id: monthHeading
            Layout.fillWidth: true
            implicitHeight: 30; padding: 0; hoverEnabled: true
            text: (I18n.trArray("calendar.months")[root.month.getMonth()] || "") + " " + root.month.getFullYear()
            Accessible.name: text + " — " + I18n.tr("calendar.back_to_today")
            background: Rectangle { radius: 8; color: monthHeading.hovered || monthHeading.visualFocus ? PolyTheme.Theme.color("#333f37") : "transparent" }
            contentItem: Text { text: monthHeading.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 14 }
            onClicked: { root.month = new Date(ClockState.date.getFullYear(), ClockState.date.getMonth(), 1); root.selected = ClockState.date; }
        }
        BarButton { symbol: "chevron-right"; hint: I18n.tr("calendar.next_month"); onClicked: root.shift(1) }
    }
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 49 + ((root.compact ? 208 : 238) - 49) * root.expansion
        columns: 7; columnSpacing: 4; rowSpacing: 4 * root.expansion
        Repeater {
            model: I18n.trArray("calendar.weekdays")
            Text {
                required property string modelData
                Layout.fillWidth: true; Layout.preferredHeight: 22
                text: modelData; color: Session.muted
                font.family: Session.fontFamily; font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
        Repeater {
            model: 42
            Button {
                id: day
                transform: InteractionMotion { item: day; pressed: day.down; hovered: day.hovered || day.visualFocus; hoverScale: 1.06 }
                required property int index
                readonly property date date: new Date(root.month.getFullYear(), root.month.getMonth(), index - root.firstOffset + 1)
                readonly property bool current: date.getMonth() === root.month.getMonth()
                readonly property bool chosen: date.toDateString() === root.selected.toDateString()
                readonly property bool isToday: date.toDateString() === ClockState.date.toDateString()
                readonly property real rowPresence: Math.floor(index / 7) === root.selectedWeek ? 1 : root.expansion
                Layout.fillWidth: true; Layout.preferredHeight: (root.compact ? 27 : 32) * rowPresence
                Layout.minimumHeight: 0; Layout.maximumHeight: (root.compact ? 27 : 32) * rowPresence
                opacity: rowPresence; clip: true; enabled: root.expansion > 0.9
                padding: 0; hoverEnabled: true
                Accessible.name: date.toLocaleDateString(root.locale, "d MMMM yyyy")
                background: Rectangle {
                    radius: 9
                    color: day.chosen ? PolyTheme.Theme.color("#9faf8e") : (day.hovered ? PolyTheme.Theme.color("#3b4640") : "transparent")
                    border.width: day.visualFocus || day.isToday ? 1 : 0
                    border.color: PolyTheme.Theme.color("#b4c49e")
                    Behavior on color { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } }
                }
                contentItem: Text {
                    text: day.date.getDate()
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    color: day.chosen ? PolyTheme.Theme.color("#222b24") : (day.current ? Session.foreground : PolyTheme.Theme.color("#68736e"))
                    font.family: Session.fontFamily; font.pixelSize: 12
                }
                Rectangle {
                    visible: DayState.data.events.some(item => item.date === DayState.dateKey(day.date))
                    anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 5
                    width: 3; height: 3; radius: 2; color: day.chosen ? PolyTheme.Theme.color("#384733") : PolyTheme.Theme.color("#d0ad87")
                }
                onClicked: root.selected = date
            }
        }
    }
    Item { visible: root.compact; Layout.fillHeight: true }
    Rectangle { visible: root.showFooter; Layout.fillWidth: true; implicitHeight: 1; color: PolyTheme.Theme.color("#3a443e") }
    RowLayout {
        visible: root.showFooter
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.selected.toLocaleDateString(root.locale, "d MMMM, dddd")
            color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11
            elide: Text.ElideRight
        }
        Button {
            text: I18n.tr("calendar.today"); flat: true
            onClicked: { root.month = new Date(ClockState.date.getFullYear(), ClockState.date.getMonth(), 1); root.selected = ClockState.date; }
            palette.buttonText: PolyTheme.Theme.color("#b4c49e")
        }
    }
}
