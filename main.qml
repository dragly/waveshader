import QtQuick 2.3
import QtQuick.Controls 1.2
import QtGraphicalEffects 1.0

ApplicationWindow {
    id: applicationRoot
    visible: true
    width: 640
    height: 640
    title: qsTr("Waveshader")

    Timer {
        id: timer
        property int turn: 0
        running: true
        repeat: true
        interval: 1
        onTriggered: {
            switch(turn) {
            case 0:
                solutionNext.update()
                break
            case 1:
                solutionPrevious.live = false
                solutionPrevious.sourceItem = solution
                solutionPrevious.scheduleUpdate()
                break
            case 2:
                solution.live = false
                solution.sourceItem = solutionNext
                solution.scheduleUpdate()
                break
            }
            turn += 1
            if(turn > 2) {
                turn = 0
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: timer.stop()
    }

    Image {
        id: rect
        anchors.fill: parent
//        color: Qt.rgba(0.5, 0.5, 0.5, 1.0)
        source: "gaussian.png"

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.5, 0.5, 0.5, 0.0)
        }

//        RadialGradient {
//            anchors.centerIn: parent
//            width: 100
//            height: 100
//            gradient: Gradient {
//                GradientStop { position: 0.0; color: Qt.rgba(0.55, 0.5, 0.5, 1.0)}
//                GradientStop { position: 0.5; color: Qt.rgba(0.5, 0.5, 0.5, 1.0) }
//            }
//        }
    }

    ShaderEffectSource {
        id: initial
        anchors.fill: parent

        sourceItem: rect
        width: applicationRoot.width / 3
    }

    ShaderEffectSource {
        id: solutionPrevious
        anchors.fill: parent

        sourceItem: rect
        recursive: true
        width: applicationRoot.width / 3
    }

    ShaderEffectSource {
        id: solution
        anchors.fill: parent

        sourceItem: rect
        recursive: true
        width: applicationRoot.width / 3
    }

    ShaderEffect {
        id: solutionNext

        property variant backbuffer: solution
        property variant backbuffer2: solutionPrevious
        property variant backbuffer3: initial
        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d mouse: Qt.vector2d(0,0)
        property real dampingFactor: 0.1
        property real dt: 0.0249567*0.7
        property real dr: 0.0392157
        property real factor: 1.0/(1+0.5*dampingFactor*dt)
        property real factor2: -(1.0-0.5*dampingFactor*dt)
        property real dtDtOverDrDr: dt*dt/(dr*dr)

        anchors.fill: parent
        fragmentShader: "
            uniform sampler2D backbuffer;
            uniform sampler2D backbuffer2;
            uniform sampler2D backbuffer3;
            uniform float factor;
            uniform float factor2;
            uniform float dtDtOverDrDr;
            uniform vec2 mouse;
            uniform vec2 resolution;

            float pack(vec3 bytes){
                bytes = bytes * vec3(255.0, 255.0, 255.0);
                round(bytes);
                return (bytes.x * 65536.0) + (bytes.y * 256.0) + bytes.z;
            }

            vec3 unpack(float value){
                vec3 ret = vec3(0.0, 0.0, 0.0);
                int totalBytes = 3;
                float radixMax = 0.0;
                int place = 0;
                for(int i = 3; i > 0; --i){
                    radixMax = pow(256.0, float(i - 1));
                    place = (3 - i);
                    if(value >= radixMax){
                        if (place == 2)
                            ret[2] = floor(value / radixMax);
                        else if (place == 1)
                            ret[1] = floor(value / radixMax);
                        else if (place == 0)
                            ret[0] = floor(value / radixMax);
                        value = mod(value, radixMax);
                    }
                }
                return (ret / vec3(255.0, 255.0, 255.0));
            }

            vec2 normalizedTexCoord(vec2 coord) {
                return coord / resolution;
            }

            void main(void) {
//                float offset = 256*256 / 2.0;
                float offset = 0.0;
                vec2 selfCoord = vec2(gl_FragCoord.x, gl_FragCoord.y);
                vec2 upCoord = selfCoord + vec2(0.0, 1.0);
                vec2 downCoord = selfCoord + vec2(0.0, -1.0);
                vec2 leftCoord = selfCoord + vec2(-1.0, 0.0);
                vec2 rightCoord = selfCoord + vec2(1.0, 0.0);
                float solution = pack(texture2D(backbuffer, normalizedTexCoord(selfCoord)).rgb) - offset;
                float solutionPrevious = pack(texture2D(backbuffer2, normalizedTexCoord(selfCoord)).rgb) - offset;
                float up = pack(texture2D(backbuffer, normalizedTexCoord(upCoord)).rgb) - offset;
                float down = pack(texture2D(backbuffer, normalizedTexCoord(downCoord)).rgb) - offset;
                float left = pack(texture2D(backbuffer, normalizedTexCoord(leftCoord)).rgb) - offset;
                float right = pack(texture2D(backbuffer, normalizedTexCoord(rightCoord)).rgb) - offset;

                float ddx = left + right;
                float ddy = up + down;

                float ddt_rest = factor2*solutionPrevious + 2*solution;

                float solutionNext = factor*(dtDtOverDrDr*(ddx + ddy - 4*solution) + ddt_rest);
//                float solutionNext = solutionPrevious;

                solutionNext += offset;

                gl_FragColor = vec4(unpack(solutionNext), 1.0);

            }"

        MouseArea {
            anchors.fill: parent
            onPositionChanged: {
                parent.mouse = Qt.vector2d(mouse.x, mouse.y)
                solutionNext.update()
//                shaderEffectSource.sourceItem = rect
            }
        }
    }

    ShaderEffectSource {
        id: postProcessSource
        anchors.fill: parent
        sourceItem: solutionNext
    }

    ShaderEffect {
        anchors.fill: parent
        property variant source: postProcessSource
        property vector2d resolution: Qt.vector2d(width, height)
        fragmentShader: "
            uniform sampler2D source;
            uniform vec2 resolution;

            float pack(vec3 bytes){
                bytes = bytes * vec3(255.0, 255.0, 255.0);
                round(bytes);
                return (bytes.x * 65536.0) + (bytes.y * 256.0) + bytes.z;
            }

            vec2 normalizedTexCoord(vec2 coord) {
                return coord / resolution;
            }

            void main(void) {
                vec2 selfCoord = vec2(gl_FragCoord.x, gl_FragCoord.y);
                float solution = pack(texture2D(source, normalizedTexCoord(selfCoord)).rgb);

                solution = (solution / 65536.0 / 255.0 - 0.5)*5.0;

                gl_FragColor = vec4(solution, solution, solution, 1.0);

            }"
    }

    Text {
        text: solutionNext.factor + " " + solutionNext.factor2 + " " + solutionNext.dtDtOverDrDr
        color: "white"
    }
}
