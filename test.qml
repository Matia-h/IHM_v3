import QtQuick
import QtQuick.Shapes

Window {
    id: root
    width: 800
    height: 600
    visible: true
    color: "#ffffff"

    signal userAction(var payload)

    // ─── MISE À L'ÉCHELLE DYNAMIQUE ──────────────────────────────────────────
    readonly property real svgBaseSize: 320
    readonly property real dynamicScale: Math.min(width, height) / svgBaseSize

    // ─── BATTERIE ────────────────────────────────────────────────────────────
    readonly property real batCX: 160
    readonly property real batCY: 160
    readonly property real batOuterR: 161
    readonly property real batInnerR: 105
    readonly property real batStartDeg: 80
    readonly property real batSweepAngle: 345

    function batPoint(angleDeg, radius) {
        const rad = angleDeg * Math.PI / 180
        return Qt.point(batCX + Math.cos(rad) * radius,
                        batCY - Math.sin(rad) * radius)
    }

    // ─── ÉTAT VISUEL ─────────────────────────────────────────────────────────
    property bool  battVisible: false
    property bool  isUnlocked:  false
    property bool  isDiffMode:  false

    property color e1Color:     "#27428f"
    property color e2Color:     "#27428f"
    property color e3Color:     "#27428f"
    property color e4Color:     "#27428f"
    property color eclairColor: "#27428f"

    readonly property color colorLocked:   "#27428f"
    readonly property color colorUnlocked: "#6a0dad"
    readonly property color colorActive:   "#ff8800"
    readonly property color colorClicked:  "#123456"

    function resetSegColors() {
        var c = isUnlocked ? colorUnlocked : colorLocked
        e1Color = c; e2Color = c; e3Color = c; e4Color = c; eclairColor = c
    }

    // ─── TIMERS ──────────────────────────────────────────────────────────────
    Timer { id: battHideTimer;   interval: 3000; repeat: false; onTriggered: root.battVisible = false }
    Timer { id: resetColorTimer; interval: 3000; repeat: false; onTriggered: root.resetSegColors() }
    Timer { id: longPressTimer;  interval: 1000; repeat: false
        onTriggered: root.userAction({ type: "long_press", segment: "e5" }) }

    // ─── CONNEXIONS BACKEND ──────────────────────────────────────────────────
    Connections {
        target: backend
        function onPinFailed() {
            wrongPinAnimation.restart()
            resetColorTimer.interval = 600
            resetColorTimer.restart()
        }
        function onUnlocked()              { root.isUnlocked = true;  root.isDiffMode = false; root.resetSegColors() }
        function onLocked()                { root.isUnlocked = false; root.isDiffMode = false; root.resetSegColors() }
        function onDiffModeChanged(active) { root.isDiffMode = active; root.resetSegColors() }
        function onShowBattery()           { root.battVisible = true;  battHideTimer.restart() }
        function onChargeStarted()         { root.battVisible = true;  battHideTimer.stop() }
        function onChargeStopped()         { battHideTimer.restart() }
    }

    // ─── UI ──────────────────────────────────────────────────────────────────
    Item {
        id: dialRoot
        // Mode différé : cadran rétréci à gauche pour laisser place au panneau
        width:  root.isDiffMode ? root.width * 0.60 : root.width
        height: root.height
        anchors.left: parent.left
        Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        transform: Translate { id: shakeTranslate; x: 0 }

        Item {
            id: scaledContainer
            anchors.centerIn: parent
            width:  svgBaseSize
            height: svgBaseSize
            scale:  root.dynamicScale
            transformOrigin: Item.Center

            // ══════════════════════════════════════════════════════════════════
            // BATTERIE — code original inchangé
            // ══════════════════════════════════════════════════════════════════
            Shape {
                anchors.fill: parent
                visible: root.battVisible
                ShapePath {
                    id: batteryFill
                    fillGradient: ConicalGradient {
                        centerX: root.batCX; centerY: root.batCY
                        angle: 98
                        GradientStop { position: 0.0;  color: "#20c50e" }
                        GradientStop { position: 0.45; color: "#eeff00" }
                        GradientStop { position: 0.83; color: "#c00a00" }
                    }
                    strokeColor: "transparent"
                    property real endDeg:   root.batStartDeg - backend.batteryLevel * root.batSweepAngle
                    property bool largeArc: (root.batStartDeg - endDeg) > 180
                    startX: root.batPoint(root.batStartDeg, root.batOuterR).x
                    startY: root.batPoint(root.batStartDeg, root.batOuterR).y
                    PathArc {
                        x: root.batPoint(batteryFill.endDeg, root.batOuterR).x
                        y: root.batPoint(batteryFill.endDeg, root.batOuterR).y
                        radiusX: root.batOuterR; radiusY: root.batOuterR
                        useLargeArc: batteryFill.largeArc
                    }
                    PathLine { x: root.batPoint(batteryFill.endDeg, root.batInnerR).x; y: root.batPoint(batteryFill.endDeg, root.batInnerR).y }
                    PathArc {
                        x: root.batPoint(root.batStartDeg, root.batInnerR).x
                        y: root.batPoint(root.batStartDeg, root.batInnerR).y
                        radiusX: root.batInnerR; radiusY: root.batInnerR
                        direction: PathArc.Counterclockwise
                        useLargeArc: batteryFill.largeArc
                    }
                    PathLine { x: root.batPoint(root.batStartDeg, root.batOuterR).x; y: root.batPoint(root.batStartDeg, root.batOuterR).y }
                }
                ShapePath {
                    id: batteryBox
                    fillColor: "transparent"; strokeColor: "#ffffff"; strokeWidth: 2
                    property real endDeg: root.batStartDeg - root.batSweepAngle
                    startX: root.batPoint(root.batStartDeg, root.batOuterR).x
                    startY: root.batPoint(root.batStartDeg, root.batOuterR).y
                    PathArc {
                        x: root.batPoint(batteryBox.endDeg, root.batOuterR).x
                        y: root.batPoint(batteryBox.endDeg, root.batOuterR).y
                        radiusX: root.batOuterR; radiusY: root.batOuterR; useLargeArc: true
                    }
                    PathLine { x: root.batPoint(batteryBox.endDeg, root.batInnerR).x; y: root.batPoint(batteryBox.endDeg, root.batInnerR).y }
                    PathArc {
                        x: root.batPoint(root.batStartDeg, root.batInnerR).x
                        y: root.batPoint(root.batStartDeg, root.batInnerR).y
                        radiusX: root.batInnerR; radiusY: root.batInnerR
                        direction: PathArc.Counterclockwise; useLargeArc: true
                    }
                    PathLine { x: root.batPoint(root.batStartDeg, root.batOuterR).x; y: root.batPoint(root.batStartDeg, root.batOuterR).y }
                }
            }

            // Cache extérieur SVG batterie — code original inchangé
            Shape {
                anchors.fill: parent
                visible: root.battVisible
                ShapePath {
                    fillColor: "#ffffff"; strokeColor: "transparent"
                    PathSvg { path: "M0,0 L320,0 L320,320 L0,320 Z M194.0904,32.2908a139.0649,139.0649,0,0,1,109.95,118.6866C314.5111,232.0515,257.744,306.2046,177.2467,316.6036c-85.6619,11.0661-164.1372-49.9038-175.2794-136.18C-8.3495,100.5384,36.532,18.1565,111.4975,0.9638c21.952-5.0345,38.6205,32.2686,17.471,46.5793-8.0878,5.4726-41.6775,13.33-64.7992,46.3631a119.4859,119.4859,0,1,0,126.3076-47.644,10.5046,10.5046,0,0,1-2.4947-8.0994C188.2758,34.4483,191.2182,32.0065,194.0904,32.2908Z" }
                }
                ShapePath {
                    fillColor: "transparent"; strokeColor: "#ffffff"; strokeWidth: 2
                    PathSvg { path: "M194.0904,32.2908a139.0649,139.0649,0,0,1,109.95,118.6866C314.5111,232.0515,257.744,306.2046,177.2467,316.6036c-85.6619,11.0661-164.1372-49.9038-175.2794-136.18C-8.3495,100.5384,36.532,18.1565,111.4975,0.9638c21.952-5.0345,38.6205,32.2686,17.471,46.5793-8.0878,5.4726-41.6775,13.33-64.7992,46.3631a119.4859,119.4859,0,1,0,126.3076-47.644,10.5046,10.5046,0,0,1-2.4947-8.0994C188.2758,34.4483,191.2182,32.0065,194.0904,32.2908Z" }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // SEGMENTS — code original inchangé
            // ══════════════════════════════════════════════════════════════════
            Item {
                id: svgScaleWrapper
                anchors.fill: parent
                transform: Scale { xScale: 320/305.9617; yScale: 320/317.8175 }

                Shape {
                    id: e1Shape; x: -10.2624; y: -15.2508
                    width: parent.width + 20; height: parent.height + 20
                    containsMode: Shape.FillContains
                    layer.enabled: true
                    layer.samples: 8
                    layer.textureSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
                    ShapePath { id: e1; fillColor: root.e1Color; strokeColor: "#ffffff"; strokeWidth: 0.96
                        PathSvg { path: "M276.7456,173.2508l-40.98-22.752h-.01a69.4275,69.4275,0,0,0-53.6881-40.1841L186.3836,75.5A103.8736,103.8736,0,0,1,276.7456,173.2508Z" } }
                }
                Shape {
                    id: e2Shape; x: -10.2624; y: -15.2508
                    width: parent.width + 20; height: parent.height + 20
                    containsMode: Shape.FillContains
                    layer.enabled: true
                    layer.samples: 8
                    layer.textureSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
                    ShapePath { id: e2; fillColor: root.e2Color; strokeColor: "#ffffff"; strokeWidth: 0.96
                        PathSvg { path: "M184.013,75.2513l-4.3157,34.8142a69.4407,69.4407,0,0,0-74.0635,43.1574l-31.98-12.2511a103.8845,103.8845,0,0,1,96.9747-66.5857A102.4759,102.4759,0,0,1,184.013,75.2513Z" } }
                }
                Shape {
                    id: e3Shape; x: -10.2624; y: -15.2508
                    width: parent.width + 20; height: parent.height + 20
                    containsMode: Shape.FillContains
                    layer.enabled: true
                    layer.samples: 8
                    layer.textureSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
                    ShapePath { id: e3; fillColor: root.e3Color; strokeColor: "#ffffff"; strokeWidth: 0.96
                        PathSvg { path: "M138.8022,243.1888l-16.6167,29.5439A103.96,103.96,0,0,1,73.032,143.1911l31.98,12.2511a69.4483,69.4483,0,0,0,33.79,87.7466Z" } }
                }
                Shape {
                    id: e4Shape; x: -10.2624; y: -15.2508
                    width: parent.width + 20; height: parent.height + 20
                    containsMode: Shape.FillContains
                    layer.enabled: true
                    layer.samples: 8
                    layer.textureSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
                    ShapePath { id: e4; fillColor: root.e4Color; strokeColor: "#ffffff"; strokeWidth: 0.96
                        PathSvg { path: "M250.1639,250.0555a103.9209,103.9209,0,0,1-125.9817,23.8161l16.6167-29.5439a69.4,69.4,0,0,0,83.57-17.2828Z" } }
                }
                Shape {
                    id: eclairShape; anchors.fill: parent
                    containsMode: Shape.FillContains
                    layer.enabled: true
                    layer.samples: 8
                    layer.textureSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
                    ShapePath { id: eclair; fillColor: root.eclairColor; strokeColor: "#ffffff"; strokeWidth: 0.96
                        PathSvg { path: "M264.933,158.926 L198.997,169.595 L218.43,180.283 L114.464,205.546 L164.99,177.368 L144.585,163.765 L224.882,136.685 Z" } }
                }

                // ICÔNES A — mode normal — code original inchangé
                Shape {
                    anchors.fill: parent
                    visible: root.isUnlocked && !root.isDiffMode
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M220.4503,97.448a1.102,1.102,0,0,1-1.1019-1.102V89.734a1.102,1.102,0,0,1,2.2039,0v6.6116A1.102,1.102,0,0,1,220.4503,97.448Zm8.8682,2.2038a8.8157,8.8157,0,0,0-3.78-7.2287,1.1019,1.1019,0,0,0-1.2562,1.8072,6.6116,6.6116,0,1,1-7.5593,0,1.1019,1.1019,0,1,0-1.2562-1.8072,8.8155,8.8155,0,1,0,13.8514,7.2287Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M115.4209,94.23a3.3617,3.3617,0,0,1-1.0588.1853,3.4009,3.4009,0,1,1,3.4008-3.4009c0,.1138-.0226.2213-.0335.3322a4.8592,4.8592,0,0,1,3.9074-.5152c-.0087-.2611-.0241-.519-.0536-.7678l2.05-1.6053a.4934.4934,0,0,0,.1169-.6219l-1.9433-3.3606a.4861.4861,0,0,0-.5921-.2124l-2.4191.9717a7.0844,7.0844,0,0,0-1.6452-.956l-.369-2.572a.476.476,0,0,0-.4757-.4093h-3.8867a.4757.4757,0,0,0-.4757.4093l-.369,2.572a7.48,7.48,0,0,0-1.6452.956l-2.419-.9717a.4712.4712,0,0,0-.5922.2124l-1.9433,3.3606a.4808.4808,0,0,0,.1169.6219l2.05,1.6053a6.8515,6.8515,0,0,0,0,1.9017l-2.05,1.6054a.4933.4933,0,0,0-.1169.6219l1.9433,3.36a.486.486,0,0,0,.5922.2125l2.419-.9716a7.082,7.082,0,0,0,1.6452.9559l.369,2.5719a.4757.4757,0,0,0,.4757.4094h3.8867a.476.476,0,0,0,.4757-.4094l.1045-.7286a4.9738,4.9738,0,0,1-1.4647-5.3631Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M120.2999,91.3251a4.45,4.45,0,1,0,4.45,4.45A4.45,4.45,0,0,0,120.2999,91.3251Zm0,7.4962a3.0463,3.0463,0,1,1,3.0462-3.0463A3.0462,3.0462,0,0,1,120.2999,98.8213Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M120.7737,95.6412V93.622a.4768.4768,0,0,0-.9535,0v2.2633c0,.007.0037.0129.004.02a.4746.4746,0,0,0,.02.0974.4593.4593,0,0,0,.0235.0822,1.128,1.128,0,0,0,.1057.1459c.008.0077.0114.0182.02.0254l1.3063,1.0961a.4863.4863,0,1,0,.6252-.7451Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M77.5036,190.59h.0628a.83.83,0,0,1,.83.83v3.0332a.83.83,0,0,1-.83.83h-.0628a.83.83,0,0,1-.83-.83V191.42A.83.83,0,0,1,77.5036,190.59Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M85.2305,183.0756H70.6152a2.6213,2.6213,0,0,0-2.6136,2.6136v14.6106a2.6213,2.6213,0,0,0,2.6136,2.6136h8.0012a2.6213,2.6213,0,0,0,2.6136-2.6136V185.689a2.57,2.57,0,0,0-.16-.8675h3.72a1.3256,1.3256,0,0,1,1.3217,1.3217v16.1339a.638.638,0,0,0,.6361.6361h.46a.638.638,0,0,0,.6361-.6361V185.689A2.6214,2.6214,0,0,0,85.2305,183.0756Zm-5.6922,16.9161a1.1359,1.1359,0,0,1-1.1327,1.1326H70.8794a1.1359,1.1359,0,0,1-1.1327-1.1326V185.9545a1.136,1.136,0,0,1,1.1327-1.1326h7.5386a1.136,1.136,0,0,1,1.1327,1.1326Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M84.3,189.096L83.056,189.815L81.812,190.533L83.056,191.251L84.3,191.969V191.212H85.473V189.853H84.3Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M82.887,194.435V195.192H81.714V196.551H82.887V197.308L84.131,196.589L85.374,195.871L84.131,195.153Z" } }
                }

                // ICÔNES B — mode différé — code original inchangé
                Shape {
                    anchors.fill: parent
                    visible: root.isUnlocked && root.isDiffMode
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M213.416,97.6543h14.1732v3.4067H213.416Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M121.551,89.355H116.168V83.972H112.761V89.355H107.378V92.762H112.761V98.145H116.168V92.762H121.551Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M85.86,195.825L80.003,188.845L78.773,187.38L76.633,189.931L71.687,195.825L74.199,197.933L78.773,192.482L83.348,197.933Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M169.858,247.778L175.715,254.759L176.945,256.224L179.085,253.673L184.031,247.778L181.519,245.67L176.945,251.122L172.37,245.67Z" } }
                    ShapePath { fillColor: "white"; strokeColor: "transparent"
                        PathSvg { path: "M188.151,167.309L185.742,164.9L178.129,172.513L174.824,169.208L172.415,171.617L175.72,174.922L178.129,177.331L180.538,174.922Z" } }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // MOUSE AREA — code original inchangé
        // ══════════════════════════════════════════════════════════════════════
        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true

            property bool  dragging:  false
            property point pressPos
            property var   visitedSegments: ({})
            readonly property int dragThreshold: 10
            property real lastOuterClick: 0

            function segmentAtPoint(p) {
                var lp = clickArea.mapToItem(svgScaleWrapper, p.x, p.y)
                var lp_seg = Qt.point(lp.x + 10.2624, lp.y + 15.2508)
                if (e1Shape.contains(lp_seg))  return "e1"
                if (e2Shape.contains(lp_seg))  return "e2"
                if (e3Shape.contains(lp_seg))  return "e3"
                if (e4Shape.contains(lp_seg))  return "e4"
                if (eclairShape.contains(lp))  return "e5"
                return null
            }

            onPressed: (mouse) => {
                dragging = false
                pressPos = Qt.point(mouse.x, mouse.y)
                visitedSegments = ({})
                if (root.isUnlocked) {
                    var seg = segmentAtPoint(Qt.point(mouse.x, mouse.y))
                    if (seg === "e5") longPressTimer.restart()
                }
            }

            onReleased: (mouse) => {
                longPressTimer.stop()
                var p = Qt.point(mouse.x, mouse.y)
                var seg = segmentAtPoint(p)

                if (!dragging) {
                    if (seg) {
                        if (seg === "e1") root.e1Color = root.colorClicked
                        else if (seg === "e2") root.e2Color = root.colorClicked
                        else if (seg === "e3") root.e3Color = root.colorClicked
                        else if (seg === "e4") root.e4Color = root.colorClicked
                        else if (seg === "e5") root.eclairColor = root.colorClicked

                        root.userAction({ type: "click", segment: seg })

                        resetColorTimer.interval = 300   // click flash
                        resetColorTimer.restart()
                    }
                } else {
                    root.userAction({ type: "drag", segments: Object.keys(visitedSegments) })

                    resetColorTimer.interval = 150   // 🔥 shorter for drag
                    resetColorTimer.restart()
                }
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return
                var dx = mouse.x - pressPos.x
                var dy = mouse.y - pressPos.y
                if (!dragging && Math.sqrt(dx*dx + dy*dy) > dragThreshold) {
                    dragging = true
                    longPressTimer.stop()
                }
                if (dragging) {
                    var seg = segmentAtPoint(Qt.point(mouse.x, mouse.y))
                    if (seg && !visitedSegments[seg]) {
                        visitedSegments[seg] = true
                        if (seg === "e1") root.e1Color     = root.colorActive
                        else if (seg === "e2") root.e2Color = root.colorActive
                        else if (seg === "e3") root.e3Color = root.colorActive
                        else if (seg === "e4") root.e4Color = root.colorActive
                        else if (seg === "e5") root.eclairColor = root.colorActive
                    }
                }
            }
        }

        SequentialAnimation {
            id: wrongPinAnimation
            running: false
            PropertyAnimation { target: shakeTranslate; property: "x"; to: -12; duration: 50 }
            PropertyAnimation { target: shakeTranslate; property: "x"; to:  12; duration: 100 }
            PropertyAnimation { target: shakeTranslate; property: "x"; to:  -8; duration: 80 }
            PropertyAnimation { target: shakeTranslate; property: "x"; to:   8; duration: 80 }
            PropertyAnimation { target: shakeTranslate; property: "x"; to:   0; duration: 60 }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PANNEAU MODE DIFFÉRÉ — NOUVEAU — s'ouvre à droite du cadran
    // ═════════════════════════════════════════════════════════════════════════
    Item {
        id: diffPanel
        visible: root.isDiffMode
        opacity: root.isDiffMode ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        anchors.left:   dialRoot.right
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Mode Différé"
                color: "#6a0dad"; font.pixelSize: 17; font.bold: true
            }

            // ── Chiffres éditables : HH:MM  BB% ─────────────────────────────
            // Curseur violet sur le chiffre actif (backend.cursorPos 0-5)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                Repeater {
                    // index : 0=Hd 1=Hu 2=: 3=Md 4=Mu 5=espace 6=Bd 7=Bu 8=%
                    model: 9
                    delegate: Item {
                        property bool isSep: (index === 2 || index === 5 || index === 8)
                        property int logIdx: {
                            if (index === 0) return 0
                            if (index === 1) return 1
                            if (index === 3) return 2
                            if (index === 4) return 3
                            if (index === 6) return 4
                            if (index === 7) return 5
                            return -1
                        }
                        property bool isActive: !isSep && (logIdx === backend.cursorPos)
                        property string dispChar: {
                            if (index === 2) return ":"
                            if (index === 5) return " "
                            if (index === 8) return "%"
                            var h = backend.editHour
                            var m = backend.editMinute
                            var b = backend.editBattery
                            if (index === 0) return Math.floor(h / 10).toString()
                            if (index === 1) return (h % 10).toString()
                            if (index === 3) return Math.floor(m / 10).toString()
                            if (index === 4) return (m % 10).toString()
                            if (index === 6) return b === 100 ? "10" : Math.floor(b / 10).toString()
                            if (index === 7) return b === 100 ? "0"  : (b % 10).toString()
                            return ""
                        }
                        width:  index === 2 ? 14 : index === 5 ? 10 : index === 8 ? 20 : 36
                        height: 60
                        Rectangle {
                            anchors.fill: parent; radius: 6
                            color:        isActive ? "#6a0dad" : "transparent"
                            border.color: (!isSep && !isActive) ? "#cccccc" : "transparent"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text:        dispChar
                                color:       isActive ? "#ffffff" : "#222222"
                                font.pixelSize: index === 2 ? 24 : index === 8 ? 13 : 28
                                font.bold:   true
                                font.family: "Courier New, monospace"
                            }
                        }
                    }
                }
            }

            // Labels sous les chiffres
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                Repeater {
                    model: [" H"," H","  "," M"," M","  "," B"," B","  "]
                    Text {
                        width: index === 2 ? 14 : index === 5 ? 10 : index === 8 ? 20 : 36
                        text: modelData; color: "#aaaaaa"; font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Rectangle { width: 190; height: 1; color: "#e0e0e0"; anchors.horizontalCenter: parent.horizontalCenter }

            // Heure figée (au moment de l'entrée en mode)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                Text { text: "Heure :"; color: "#555555"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 82; height: 38; radius: 7; color: "#f4f4f4"; border.color: "#cccccc"; border.width: 1
                    Text { anchors.centerIn: parent; text: backend.time
                        font.pixelSize: 17; font.bold: true; color: "#222222"; font.family: "Courier New, monospace" }
                }
            }

            // Batterie actuelle
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                Text { text: "Batterie :"; color: "#555555"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 82; height: 38; radius: 7; color: "#f4f4f4"; border.color: "#cccccc"; border.width: 1
                    Text { anchors.centerIn: parent; text: backend.batteryPercent + " %"
                        font.pixelSize: 17; font.bold: true; color: "#222222"; font.family: "Courier New, monospace" }
                }
            }
        }
    }
}
