/*
* Forum Browser
*
* Copyright (c) 2014-2015 Niklas Wenzel <nikwen.developer@gmail.com>
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.3
import Ubuntu.Components 1.1
import Ubuntu.Components.ListItems 1.0 as ListItem
import "../components"

Page {
    id: settingsPage
    title: i18n.tr("Settings")

    Flickable {
        anchors.fill: parent

        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            height: childrenRect.height

//            ListItem.Header {
//                text: i18n.tr("Display settings")
//            }

            CheckboxSubtitledListItem {
                id: useAlternativeDateFormatListItem
                text: i18n.tr("Alternative date format")
                //TRANSLATORS: Setting to switch between the date formats used in MessageDelegate.qml. Please format the example dates accordingly.
                subText: backend.useAlternativeDateFormat ? i18n.tr("Current format: At 11:54, On March 7, On April 10, 2015") : i18n.tr("Current format: 28 minutes ago, 14 hours ago, March 2015")
                checked: backend.useAlternativeDateFormat

                onClicked: {
                    checked = !checked
                }

                onCheckedChanged: {
                    backend.useAlternativeDateFormat = checked
                }

                Connections {
                    target: backend

                    onUseAlternativeDateFormatChanged: {
                        useAlternativeDateFormatListItem.checked = backend.useAlternativeDateFormat
                    }
                }
            }

            CheckboxSubtitledListItem {
                id: showSubjectFieldForRepliesListItem
                text: i18n.tr("Subject field when writing a reply")
                checked: backend.subjectFieldWhenReplying

                onClicked: {
                    checked = !checked
                }

                onCheckedChanged: {
                    backend.subjectFieldWhenReplying = checked
                }

                Connections {
                    target: backend

                    onSubjectFieldWhenReplyingChanged: {
                        showSubjectFieldForRepliesListItem.checked = backend.subjectFieldWhenReplying
                    }
                }
            }

//            ListItem.Header {
//                text: i18n.tr("Identity settings")
//            }

            OneLineSubtitledListItem {
                text: i18n.tr("Signature")
                subText: (backend.signature !== "") ? backend.signature : i18n.tr("Displays a signature below all of your posts…")
                progression: true

                onClicked: {
                    pageStack.push(Qt.resolvedUrl("EditSignaturePage.qml"))
                }
            }
        }
    }
}
