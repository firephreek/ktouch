/*
 *  Copyright 2012  Sebastian Gottfried <sebastiangottfried@web.de>
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License as
 *  published by the Free Software Foundation; either version 2 of
 *  the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 1.1
import org.kde.plasma.core 0.1 as PlasmaCore
import ktouch 1.0

FocusScope {

    id: screen

    property KeyboardLayout keyboardLayout
    property Profile profile
    property Course course
    property Lesson lesson

    property alias stats: stats
    property alias referenceStats: referenceStats

    signal restartRequested()
    signal abortRequested()
    signal finished()

    property bool trainingStarted: false
    property bool trainingFinished: true
    property bool isActive

    function setLessonKeys() {
        if (!lesson)
            return;

        var chars = lesson.characters;
        var keyItems = keyboard.keyItems()
        var modifierItems = []
        var usedModifiers = {}

        for (var i = 0; i < keyItems.length; i++) {
            var key = keyItems[i].key
            if (key.keyType() == "key") {
                keyItems[i].enabled = false;
                for (var j = 0; j < key.keyCharCount; j++) {
                    var keyChar = key.keyChar(j)
                    if (chars.indexOf(String.fromCharCode(keyChar.value)) != -1) {
                        keyItems[i].enabled = true;
                        if (keyChar.modifier !== "") {
                            usedModifiers[keyChar.modifier] = true
                        }
                    }
                }
            }
            else {
                var type = keyItems[i].key.type
                if (type != SpecialKey.Return && type != SpecialKey.Backspace && type != SpecialKey.Space)
                {
                    modifierItems.push(keyItems[i])
                    keyItems[i].enabled = false
                }
            }
        }

        for (i = 0; i < modifierItems.length; i++) {
            var modifierItem = modifierItems[i]
            modifierItem.enabled = !!usedModifiers[modifierItem.key.modifierId]
        }
    }

    function reset() {
        toolbar.reset()
        trainingWidget.reset()
        screen.trainingStarted = false
        screen.trainingFinished = true
        profileDataAccess.loadReferenceTrainingStats(referenceStats, screen.profile, screen.course.id, screen.lesson.id)
    }

    function start() {
        screen.trainingFinished = false
        screen.trainingStarted = true
    }

    onLessonChanged: setLessonKeys()

    TrainingStats {
        id: stats
        onTimeIsRunningChanged: {
            if (timeIsRunning)
                screen.trainingStarted = false
        }
    }

    TrainingStats {
        id: referenceStats
    }

    PlasmaCore.Svg {
        id: screenSvg
        imagePath: findImage("trainingscreen.svgz")
        usingRenderingCache: false
    }

    Column {
        anchors.fill: parent

        TrainingScreenToolbar {
            id: toolbar
            height: 29
            width: parent.width
            trainingStarted: screen.trainingStarted
            trainingFinished: screen.trainingFinished
            menuOverlayItem: menuOverlay
        }

        PlasmaCore.SvgItem {
            id: header
            svg: screenSvg
            elementId: "header"
            width: parent.width
            visible: preferences.showStatistics
            height: visible? 120: 0
            Row {
                anchors.centerIn: parent
                spacing: 10
                EllapsedTimeMeter {
                    ellapsedTime: stats.ellapsedTime
                    referenceEllapsedTime: referenceStats.isValid? referenceStats.ellapsedTime: stats.ellapsedTime
                }
                CharactersPerMinuteMeter {
                    charactersPerMinute: stats.charactersPerMinute
                    referenceCharactersPerMinute: referenceStats.isValid? referenceStats.charactersPerMinute: stats.charactersPerMinute
                }
                AccuracyMeter {
                    accuracy: stats.accuracy
                    referenceAccuracy: referenceStats.isValid? referenceStats.accuracy: stats.accuracy
                }
            }
        }

        PlasmaCore.SvgItem {
            id: body
            width: parent.width
            height: parent.height - toolbar.height - header.height - footer.height
            svg: screenSvg
            elementId: "content"

            TrainingWidget {
                id: trainingWidget
                anchors.fill: parent
                lesson: screen.lesson
                onKeyPressed: keyboard.handleKeyPress(event)
                onKeyReleased: keyboard.handleKeyRelease(event)
                onNextCharChanged: keyboard.updateKeyHighlighting()
                onIsCorrectChanged: keyboard.updateKeyHighlighting()
                onFinished: {
                    profileDataAccess.saveTrainingStats(stats, screen.profile, screen.course.id, screen.lesson.id)
                    screen.finished(stats)
                    screen.trainingFinished = true
                }
            }

            PlasmaCore.FrameSvgItem {
                anchors.fill: parent
                imagePath: findImage("trainingscreen.svgz")
                prefix: "content-shadow"
            }
        }

        PlasmaCore.SvgItem {
            id: footer
            width: parent.width
            visible: preferences.showKeyboard && screen.keyboardLayout.isValid
            height: visible? Math.round(Math.min((parent.height - toolbar.height - header.height) / 2, parent.width / keyboard.aspectRatio)): 0
            svg: screenSvg
            elementId: "footer"
            Keyboard {
                property variant highlightedKeys: []
                function highlightKey(which) {
                    for (var i = 0; i < highlightedKeys.length; i++)
                        highlightedKeys[i].isHighlighted = false
                    var key = findKeyItem(which)
                    if (key) {
                        var newHighlightedKeys = []
                        key.isHighlighted = true
                        newHighlightedKeys.push(key)
                        if (typeof which == "string") {
                            var code = which.charCodeAt(0)
                            for (var i = 0; i < key.key.keyCharCount; i++) {
                                var keyChar = key.key.keyChar(i)
                                if (keyChar.value == code && keyChar.modifier != "") {
                                    var modifier = findModifierKeyItem(keyChar.modifier)
                                    if (modifier) {
                                        modifier.isHighlighted = true
                                        newHighlightedKeys.push(modifier)
                                    }
                                    break
                                }
                            }
                        }
                        highlightedKeys = newHighlightedKeys
                    }
                }

                function updateKeyHighlighting() {
                    if (!visible)
                        return;
                    if (trainingWidget.isCorrect) {
                        if (trainingWidget.nextChar !== "") {
                            highlightKey(trainingWidget.nextChar)
                        }
                        else {
                            highlightKey(Qt.Key_Return)
                        }
                    }
                    else {
                        highlightKey(Qt.Key_Backspace)
                    }
                }

                keyboardLayout: screen.keyboardLayout
                id: keyboard
                anchors.fill: parent
                onKeyboardUpdate: {
                    setLessonKeys()
                    highlightedKeys = []
                    updateKeyHighlighting()
                }
            }
        }
    }

    TrainingScreenMenuOverlay {
        id: menuOverlay
        anchors.fill: parent
        onVisibleChanged: {
            if (!visible) {
                trainingWidget.forceActiveFocus()
            }
        }
        onRestartRequested: screen.restartRequested()
        onAbortRequested: screen.abortRequested()
    }

    Binding {
        target: screen
        property: "isActive"
        value: Qt.application.active
    }

    onIsActiveChanged: {
        if (!screen.isActive) {
            stats.stopTraining()
        }
    }
}
