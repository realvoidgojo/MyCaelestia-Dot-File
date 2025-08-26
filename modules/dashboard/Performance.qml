import qs.components
import qs.components.misc
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    readonly property int padding: Appearance.padding.large

    function displayTemp(temp: real): string {
        return `${Math.ceil(Config.services.useFahrenheit ? temp * 1.8 + 32 : temp)}°${Config.services.useFahrenheit ? "F" : "C"}`;
    }

    spacing: Appearance.spacing.large * 3

    Ref {
        service: SystemUsage
    }

    Resource {
        Layout.alignment: Qt.AlignVCenter
        Layout.topMargin: root.padding
        Layout.bottomMargin: root.padding
        Layout.leftMargin: root.padding * 2

        value1: Math.min(1, SystemUsage.gpuTemp / 90)
        value2: SystemUsage.gpuPerc

        label1: root.displayTemp(SystemUsage.gpuTemp)
        label2: `${Math.round(SystemUsage.gpuPerc * 100)}%`

        sublabel1: qsTr("GPU temp")
        sublabel2: qsTr("Usage")
    }

    Resource {
        Layout.alignment: Qt.AlignVCenter
        Layout.topMargin: root.padding
        Layout.bottomMargin: root.padding

        primary: true

        value1: Math.min(1, SystemUsage.cpuTemp / 90)
        value2: SystemUsage.cpuPerc

        label1: root.displayTemp(SystemUsage.cpuTemp)
        label2: `${Math.round(SystemUsage.cpuPerc * 100)}%`

        sublabel1: qsTr("CPU temp")
        sublabel2: qsTr("Usage")
    }

    Resource {
        Layout.alignment: Qt.AlignVCenter
        Layout.topMargin: root.padding
        Layout.bottomMargin: root.padding

        value1: SystemUsage.memPerc
        value2: SystemUsage.memTotal > 0 ? (SystemUsage.memTotal - SystemUsage.memUsed) / SystemUsage.memTotal : 0

        label1: {
            const fmt = SystemUsage.formatKib(SystemUsage.memUsed);
            const totalFmt = SystemUsage.formatKib(SystemUsage.memTotal);
            return `${fmt.value.toFixed(1)}${fmt.unit} / ${totalFmt.value.toFixed(1)}${totalFmt.unit}`;
        }
        label2: {
            const free = SystemUsage.memTotal - SystemUsage.memUsed;
            const fmt = SystemUsage.formatKib(free);
            return `${fmt.value.toFixed(1)}${fmt.unit}`;
        }

        sublabel1: qsTr("Memory")
        sublabel2: qsTr("Free")
    }

    Resource {
        Layout.alignment: Qt.AlignVCenter
        Layout.topMargin: root.padding
        Layout.bottomMargin: root.padding
        Layout.rightMargin: root.padding * 3

        value1: SystemUsage.storagePerc
        value2: SystemUsage.storageTotal > 0 ? (SystemUsage.storageTotal - SystemUsage.storageUsed) / SystemUsage.storageTotal : 0

        label1: {
            const fmt = SystemUsage.formatKib(SystemUsage.storageUsed);
            const totalFmt = SystemUsage.formatKib(SystemUsage.storageTotal);
            return `${fmt.value.toFixed(1)}${fmt.unit} / ${totalFmt.value.toFixed(1)}${totalFmt.unit}`;
        }
        label2: {
            const free = SystemUsage.storageTotal - SystemUsage.storageUsed;
            const fmt = SystemUsage.formatKib(free);
            return `${fmt.value.toFixed(1)}${fmt.unit}`;
        }

        sublabel1: qsTr("Disk Usage")
        sublabel2: qsTr("Free")
        label1FontSize: 20
    }

    // Rewrite this Resource component.
    // The text labels should always be visible on top of the canvas arcs.
    // The font sizes for the labels should be fixed, so remove the `primaryMult` scaling.
    component Resource: Item {
        id: res

        required property real value1
        required property real value2
        required property string sublabel1
        required property string sublabel2
        required property string label1
        required property string label2

        property bool primary
        property int label1FontSize: 22

        readonly property real thickness: Config.dashboard.sizes.resourceProgessThickness * (primary ? 1.2 : 1)

        property color fg1: Colours.palette.m3primary
        property color fg2: Colours.palette.m3secondary
        property color bg1: Colours.palette.m3primaryContainer
        property color bg2: Colours.palette.m3secondaryContainer

        implicitWidth: Config.dashboard.sizes.resourceSize * (primary ? 1.2 : 1)
        implicitHeight: Config.dashboard.sizes.resourceSize * (primary ? 1.2 : 1)

        onValue1Changed: canvas.requestPaint()
        onValue2Changed: canvas.requestPaint()
        onFg1Changed: canvas.requestPaint()
        onFg2Changed: canvas.requestPaint()
        onBg1Changed: canvas.requestPaint()
        onBg2Changed: canvas.requestPaint()

        Canvas {
            id: canvas
            z: -1

            readonly property real centerX: width / 2
            readonly property real centerY: height / 2

            readonly property real arc1Start: degToRad(45)
            readonly property real arc1End: degToRad(220)
            readonly property real arc2Start: degToRad(230)
            readonly property real arc2End: degToRad(360)

            function degToRad(deg: int): real {
                return deg * Math.PI / 180;
            }

            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();

                ctx.lineWidth = res.thickness;
                ctx.lineCap = Appearance.rounding.scale === 0 ? "square" : "round";

                const radius = (Math.min(width, height) - ctx.lineWidth) / 2;
                const cx = centerX;
                const cy = centerY;
                const a1s = arc1Start;
                const a1e = arc1End;
                const a2s = arc2Start;
                const a2e = arc2End;

                ctx.beginPath();
                ctx.arc(cx, cy, radius, a1s, a1e, false);
                ctx.strokeStyle = res.bg1;
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(cx, cy, radius, a1s, (a1e - a1s) * res.value1 + a1s, false);
                ctx.strokeStyle = res.fg1;
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(cx, cy, radius, a2s, a2e, false);
                ctx.strokeStyle = res.bg2;
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(cx, cy, radius, a2s, (a2e - a2s) * res.value2 + a2s, false);
                ctx.strokeStyle = res.fg2;
                ctx.stroke();
            }
        }

        Column {
            anchors.centerIn: parent

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: res.label1
                font.pixelSize: res.label1FontSize
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: res.sublabel1
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 12
            }
        }

        Column {
            anchors.horizontalCenter: parent.right
            anchors.top: parent.verticalCenter
            anchors.horizontalCenterOffset: -res.thickness / 2
            anchors.topMargin: res.thickness / 2 + Appearance.spacing.small

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: res.label2
                font.pixelSize: 12
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: res.sublabel2
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 11
            }
        }

        Behavior on value1 {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }

        Behavior on value2 {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }

        Behavior on fg1 {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }

        Behavior on fg2 {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }

        Behavior on bg1 {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }

        Behavior on bg2 {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    }
}
