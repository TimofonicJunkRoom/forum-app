import QtQuick 2.2
import Ubuntu.Components 1.1

Item {
    id: rootItem

    readonly property variant tagsWithChildren: [ "quote", "code", "hide" ] //lower-case

    property string code: ""
    property var bbRoot: parse("", [], code) //of type passage
//    onBbRootChanged: printParsedPost(bbRoot)

    height: passageView.height

    PassageView {
        id: passageView
        dataItem: bbRoot
        width: parent.width
    }

    Component {
        id: passage
        Item {
            property string tagType: ""
            property var tagArguments: []
            //Only one of the following two is used at a time
            property string text: ""
            property var childElements: []
        }
    }

    //TODO-r: Tags with arguments
    function parse(tagType, tagArguments, content) { //Post content which should be parsed
        var oldPos = 0
        var pos = -1
        var root = passage.createObject(rootItem, { "tagType": tagType, "tagArguments": tagArguments }) //TODO-r: Proper parent here

        while ((pos = content.indexOf("[", pos + 1)) !== -1) {
            var bracketClosePos = content.indexOf("]", pos + 1)

            //Check if the tag has arguments
            var equalsPos = content.indexOf("=", pos + 1)
            var spacePos = content.indexOf(" ", pos + 1)
            var argumentsStartPos = (spacePos === -1) ? equalsPos : ((equalsPos === -1) ? -1 : Math.min(equalsPos, bracketClosePos))
            var hasArguments = argumentsStartPos !== -1

            var tag = content.substring(pos + 1, hasArguments ? argumentsStartPos : bracketClosePos).toLowerCase()
            var arguments = []
//            if (hasArguments) { //TODO-r: Only works for some forums, e.g. not for XDA
//                var argumentString = content.substring(equalsPos + 2, bracketClosePos) // +2 also excludes the "equals"
//                arguments = argumentString.split(";")
//            }

            if (arrayContains(tagsWithChildren, tag)) { //else: don't parse
                var notFormattedText = content.substring(oldPos, pos)
                if (notFormattedText !== "") {
                    root.childElements.push(parse("", [], notFormattedText))
                }
                var endPos = pos + tag.length //TODO-r: Add arguments string length
                var moreStartTags = 1
                while (moreStartTags > 0) {
                    endPos = content.indexOf(tag, endPos + tag.length)
                    if (endPos === -1) {
                        console.log("Error: endPos === -1")
                        break
                    }
                    var currentTag = content.substring(content.lastIndexOf("[", endPos), content.indexOf("]", endPos) + 1).toLowerCase() //TODO-r: Why lastIndexOf()???
                    if (currentTag === "[" + tag + "]") {
                        moreStartTags++
                    } else if (currentTag === "[/" + tag + "]") { //TODO-r: What's about other tags which are closed?
                        moreStartTags--
                    }
                }
                if (moreStartTags === 0) { //else: user forgot closing tag => ignore tag
                    root.childElements.push(parse(tag, arguments, content.substring(bracketClosePos + 1, endPos - 2)))
                    oldPos = endPos + tag.length + 1
                    pos = oldPos
                }
            }
        }
        if (root.childElements.length === 0) {
            root.text = content
        } else {
            var restText = content.substring(oldPos, content.length)
            if (restText.trim() !== "") {
                root.childElements.push(parse("", [], restText))
            }
        }
        return root
    }

    function printParsedPost(root, indentation) {
        var indentationString = ""
        for (var i = 0; i < indentation; i++) {
            indentationString += " "
        }

        if (root.text !== "") {
            console.log(indentationString + root.text)
        } else {
            console.log(indentationString + "Children:")
            for (var child in root.childElements) {
                printParsedPost(root.childElements[child], indentation + 2)
            }
        }
    }

    function arrayContains(array, value) {
        for (var i = 0; i < array.length; i++) {
            if (array[i] === value) {
                return true
            }
        }
        return false
    }

    function replaceBBMarkupWithHtml(text) {
        var bb = [];
        bb[0] = /\[url\](.*?)\[\/url\]/gi;
        bb[1] = /\[url\="?(.*?)"?\](.*?)\[\/url\]/gi;
        bb[2] = /\[img\](.*?)\[\/img\]/gi;

        var html =[];
        html[0] = "<a href=\"$1\">$1</a>";
        html[1] = "<a href=\"$1\">$2</a>";
        html[2] = "<img src=\"$1\">";

        for (var i = 0; i < bb.length; i++) {
            text = text.replace(bb[i], html[i]);
        }

        return text;
    }
}
