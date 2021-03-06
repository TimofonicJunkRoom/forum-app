/*
* Forum Browser
*
* Copyright (c) 2014-2015 Niklas Wenzel <nikwen.developer@gmail.com>
* Copyright (c) 2013-2014 Michael Hall <mhall119@ubuntu.com>
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
import QtQuick.XmlListModel 2.0
import Ubuntu.Components 1.1
import Ubuntu.Components.ListItems 1.0
import "../../backend"


ListView {
    id: forumsList

    property alias current_forum: categoryModel.parentForumId
    property string mode: ""
    property bool moreLoading: false
    property bool hasTopics: false
    property bool canPost: false

    property bool viewSubscriptions: false

    readonly property bool modelsHaveLoadedCompletely: categoryModel.hasLoadedCompletely && topicModel.hasLoadedCompletely

    clip: true

    onModeChanged: reload()

    delegate: SubForumListItem {
        text: Qt.atob(model.name)
        subText: Qt.atob(model.description)
        replies: model.topic ? (model.posts + 1) : 0 //+1 to include OP
        author: model.topic ? Qt.atob(model.author) : ""
        has_new: model.has_new
        progression: true

        onTriggered: {
            if (model.topic) {
                forumsPage.pushThreadPage(model.forum_id, model.topic_id, text)
            } else {
                forumsPage.pushSubForumPage(model.forum_id, text, model.can_subscribe, model.is_subscribed)
            }
        }

        Component.onCompleted: {
            if (modelsHaveLoadedCompletely && hasTopics && mode === "" && index === forumListModel.count - 3 && forumListModel.count % backend.topicsLoadCount === categoryModel.count) {
                console.log("load more, index: " + index)
                loadMore(backend.topicsLoadCount)
            }
        }
    }

    footer: Standard { //ListItem.Standard
        visible: moreLoading && forumListModel.count > 0 //forumListModel.count > 0 for forum overview
        width: parent.width
        height: visible ? units.gu(6) : 0
        divider.visible: false

        ActivityIndicator {
            id: loadMoreIndicator
            running: visible
            anchors.centerIn: parent
        }
    }

    model: ListModel {
        id: forumListModel

        Component.onCompleted: {
            backend.currentSession.loginDone.connect(clear)
        }

        Component.onDestruction: {
            backend.currentSession.loginDone.disconnect(clear)
        }
    }

    function topicCount() {
       var count = 0;
       for (var i = 0; i < forumListModel.count; i++) {
           if (forumListModel.get(i).topic) {
               count++;
           }
       }
       return count;
    }

    function loadMore(count) {
        moreLoading = true
        var tCount = topicCount();
        topicModel.loadTopics(tCount, tCount + count - 1);
    }

    function reload() {
        forumListModel.clear()
        if (mode === "") {
            categoryModel.loadForums()
        }
        topicModel.loadTopics()
    }

    ApiRequest {
        id: categoryRequest

        onQueryResult: {
            if (withoutErrors) {
                if (isForumOverview) {
                    categoryModel.fetchedXml = responseXml
                } else {
                    categoryModel.xml = responseXml
                }
            } else {
                categoryModel.loadingFinished()
            }
        }
    }

    XmlListModel {
        id: categoryModel
        objectName: "categoryModel"

        property bool hasLoadedCompletely: true

        property string parentForumId: "-1"
        property bool viewSubscriptions: forumsList.viewSubscriptions
        query: viewSubscriptions ? "/methodResponse/params/param/value/struct/member[name='forums']/value/array/data/value/struct" : "/methodResponse/params/param/value/array/data/value/struct"

        XmlRole { name: "id"; query: "member[name='forum_id']/value/string/string()" }
        XmlRole { name: "name"; query: "member[name='forum_name']/value/base64/string()" }
        XmlRole { name: "description"; query: "member[name='description']/value/base64/string()" }
        XmlRole { name: "can_subscribe"; query: "member[name='can_subscribe']/value/boolean/number()" }
        XmlRole { name: "is_subscribed"; query: "member[name='is_subscribed']/value/boolean/number()" }

        property bool checkingForChildren: false

        //Only used if isForumOverview:
        property string fetchedXml
        property int lastFetchedPos

        onStatusChanged: {
            if (status === 1) {
//                console.log(xml) //Do not run on XDA home!!! (Too big, will freeze QtCreator)
                if (!checkingForChildren) {
                    console.debug("categoryModel has: " + count + " items");

                    if (count === 1 && parentForumId === get(0).id) { //Header with a child attribute
                        if (!topicModel.hasLoadedCompletely) {
                            topicModel.onHasLoadedCompletelyChanged.connect(loadChildren)
                        } else {
                            loadChildren()
                        }
                    } else {
                        insertResults()
                    }
                } else {
                    checkingForChildren = false
                    switch (count) {
                    case 0: //Check for id
                        console.log("no subs")
                        loadingFinished()
                        break
                    default:
                        console.log("Subs")
                        insertResults()
                    }
                }


            }
        }

        function loadChildren() { //Reloading should overall be faster than loading the children attribute for every item
            topicModel.onHasLoadedCompletelyChanged.disconnect(loadChildren)

            checkingForChildren = true

            query = "/methodResponse/params/param/value/array/data/value/struct/member[name='child']/value/array/data/value/struct"
        }

        function insertResults() { //If changed, adjust above as well
            for (var i = 0; i < count; i++) {
                var element = get(i)
                //We need to declare even unused properties here
                //Needed when there are both topics and categories in a subforum
                var pushObject = { "topic": false, "forum_id": element.id, "topic_id": "-1", "name": element.name.trim(), "description": viewSubscriptions ? "" : element.description.trim(), "author": "", "posts": -1, "has_new": false, "can_subscribe": viewSubscriptions ? true : Boolean(element.can_subscribe), "is_subscribed": viewSubscriptions ? true : Boolean(element.is_subscribed) }
                if (!isForumOverview) {
                    forumListModel.insert(i, pushObject)
                } else {
                    forumListModel.append(pushObject)
                }
            }

            loadingFinished()
        }

        function loadingFinished() {
            hasLoadedCompletely = true

            if (isForumOverview) {
                parseFetchedXml()
            }
        }

        Component.onCompleted: {
            backend.currentSession.loginDone.connect(loadForums)
        }

        Component.onDestruction: {
            backend.currentSession.loginDone.disconnect(loadForums)
        }

        onParentForumIdChanged: if (backend.currentSession.loginFinished) loadForums()
        onViewSubscriptionsChanged: if (viewSubscriptions && backend.currentSession.loginFinished) loadForums()

        function loadForums() {
            if (parentForumId < 0 && !viewSubscriptions) {
                return
            }

            console.log("loading categories")

            hasLoadedCompletely = false
            lastFetchedPos = 0

            categoryModel.xml = ""
            fetchedXml = ""

            if (!viewSubscriptions) {
                categoryRequest.query = '<?xml version="1.0"?><methodCall><methodName>get_forum</methodName><params><param><value><boolean>true</boolean></value></param><param><value>' + parentForumId + '</value></param></params></methodCall>'
            } else {
                categoryRequest.query = '<?xml version="1.0"?><methodCall><methodName>get_subscribed_forum</methodName></methodCall>'
            }
            categoryRequest.start()
        }

        onFetchedXmlChanged: parseFetchedXml()

        function parseFetchedXml() {
            if (fetchedXml === "") {
                return
            }

            var pos = getNthStructEnd(fetchedXml, (forumListModel.count < 40) ? 20 : 50, lastFetchedPos)

            if (pos < 0 && lastFetchedPos === 0) { //Not found 20 times in the whole xml response
                categoryModel.xml = fetchedXml
            } else {
                var beginningText = ""
                if (lastFetchedPos !== 0) { //add end + start
                    var beginningEndPos = fetchedXml.indexOf("<struct>")
                    beginningText = fetchedXml.substring(0, beginningEndPos)
                }

                if (pos > 0) {
                    var closingTagsPos = fetchedXml.lastIndexOf("</struct>")
                    var closingText = fetchedXml.substring(closingTagsPos + 6)

                    var middleText = fetchedXml.substring(lastFetchedPos, pos)

                    categoryModel.xml = beginningText + middleText + closingText //TODO: Remove already parsed parts for better search performance? (Would require a change in lastFetchedPos handling)

                    moreLoading = true
                } else { //Not found 20 times anymore
                    var contentText = fetchedXml.substring(lastFetchedPos)

                    categoryModel.xml = beginningText + contentText

                    fetchedXml = "" //Stops loading loop
                    moreLoading = false
                }

                lastFetchedPos = pos
            }
        }

        function getNthStructEnd(string, n, startPos) { //Returns -1 if not found n times
            if (startPos === undefined) {
                startPos = 0
            }
            var endPos = startPos

            for (var i = 0; i < n; i++) {
                startPos = string.indexOf("struct", endPos)
                var nextPos = string.indexOf("struct", startPos + 6)
                while (string.charAt(nextPos - 1) !== "/") {
                    nextPos = string.indexOf("struct", getNthStructEnd(string, 1, nextPos)) //TODO: Remove children from document? Would interfere with child-only subforums though

                    if (nextPos < 0) {
                        return -1
                    }
                }

                endPos = nextPos + 6
            }
            return endPos + 1 // + 1 for ">"
        }

    }

    ApiRequest {
        id: topicRequest

        onQueryResult: {
            if (withoutErrors) {
                topicModel.xml = responseXml
            } else {
                topicModel.loadingFinished()
            }
        }
    }

    XmlListModel {
        id: topicModel
        objectName: "topicModel"

        property bool hasLoadedCompletely: true

        property int forumId: current_forum
        property bool viewSubscriptions: forumsList.viewSubscriptions
        query: "/methodResponse/params/param/value/struct/member[name='topics']/value/array/data/value/struct"

        XmlRole { name: "id"; query: "member[name='topic_id']/value/string/string()" }
        XmlRole { name: "forum_id"; query: "member[name='forum_id']/value/string/string()" }
        XmlRole { name: "title"; query: "member[name='topic_title']/value/base64/string()" }
        XmlRole { name: "author"; query: "member[name='topic_author_name']/value/base64/string()" }
        XmlRole { name: "posts"; query: "member[name='reply_number']/value/int/number()" }
        XmlRole { name: "has_new"; query: "member[name='new_post']/value/boolean/number()" }

        onStatusChanged: {
            if (status === 1) {
                if (count > 0) {
                    hasTopics = true //no else needed (and it may interfere with moreLoading)

                    //TODO: Check if if is needed or if it won't be added twice even without the if
                    if (count === 1 && forumListModel.count > 0 && get(0).id === forumListModel.get(forumListModel.count - 1).id && forumListModel.get(forumListModel.count - 1).topic === true) {
                        //Do not add the element as it is a duplicate of the last one which was added
                        //Happens if a forum contains n * backend.topicsLoadCount topics (with n = 2, 3, 4, ...) and loadMore() is called (sadly, that's how the API handles the request)

                        console.log("Don't add duplicate topic (n * backend.topicsLoadCount posts)")

                        showNoMoreNotification()
                    } else {
                        //Add to forumListModel

                        console.debug("topicModel has: " + count + " items");

                        for (var i = 0; i < count; i++) {
                            var element = get(i);
                            //We need to declare even unused properties here
                            //Needed when there are both topics and categories in a subforum
                            forumListModel.append({ "topic": true, "forum_id": element.forum_id, "topic_id": element.id, "name": element.title.trim(), "description": "", "author": element.author.trim(), "posts": (typeof(element.posts) === "number") ? element.posts : 0, "has_new": Boolean(element.has_new), "can_subscribe": true, "is_subscribed": false });
                        }
                    }
                }

//                console.log(xml)

                //Check if the user is allowed to create a new topic

                var canPostStringPosition = xml.indexOf("<name>can_post</name>");
                if (canPostStringPosition < 0) {
                    canPost = true
                } else {
                    var openBoolTagPosition = xml.indexOf("<boolean>", canPostStringPosition);
                    var closeBoolTagPosition = xml.indexOf("</boolean>", openBoolTagPosition);
                    var canPostSubstring = xml.substring(openBoolTagPosition + 9, closeBoolTagPosition); //equals + "<boolean>".length

                    canPost = canPostSubstring.trim() === "1"
                }

                loadingFinished()
            }
        }

        function showNoMoreNotification() {
            notification.show(i18n.tr("No more threads to load"))
        }

        function loadingFinished() {
            if (count === 0 && moreLoading) {
                showNoMoreNotification()
            }

            moreLoading = false
            hasLoadedCompletely = true
        }

        Component.onCompleted: {
            backend.currentSession.loginDone.connect(loadTopics)
        }

        Component.onDestruction: {
            backend.currentSession.loginDone.disconnect(loadTopics)
        }

        onForumIdChanged: if (backend.currentSession.loginFinished) loadTopics()
        onViewSubscriptionsChanged: if (viewSubscriptions && backend.currentSession.loginFinished) loadTopics()

        function loadTopics(startNum, endNum) {
            if (forumId <= 0 && !viewSubscriptions) {
                return
            }

            console.log("loading topics")

            hasLoadedCompletely = false

            topicModel.xml = ""

            var startEndParams = ""
            if (startNum !== undefined && endNum !== undefined) {
                console.log("load topics: " + startNum + " - " + endNum)
                startEndParams += '<param><value><int>'+startNum+'</int></value></param>'
                startEndParams += '<param><value><int>'+endNum+'</int></value></param>'
            } else {
                startEndParams += '<param><value><int>0</int></value></param>'
                startEndParams += '<param><value><int>' + (backend.topicsLoadCount - 1) + '</int></value></param>'
            }

            if (!viewSubscriptions) {
                topicRequest.query = '<?xml version="1.0"?><methodCall><methodName>get_topic</methodName><params><param><value>' + forumId + '</value></param>' + startEndParams + '<param><value>' + mode + '</value></param></params></methodCall>'
            } else {
                topicRequest.query = '<?xml version="1.0"?><methodCall><methodName>get_subscribed_topic</methodName><params>' + startEndParams + '</params></methodCall>'
            }
            topicRequest.start()
        }
    }



}
