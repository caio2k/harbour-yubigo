import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5

Page {
    id: page

    property var keys

    // The effective value will be restricted by ApplicationWindow.allowedOrientations
    allowedOrientations: Orientation.All

    onStatusChanged: {
        if ((status == Component.Ready))
        {
            python.getKeys();
        }
    }

    // To enable PullDownMenu, place our content in a SilicaFlickable
    SilicaFlickable {
        anchors.fill: parent

        // PullDownMenu and PushUpMenu must be declared in SilicaFlickable, SilicaListView or SilicaGridView
        PullDownMenu {
            MenuItem {
                text: qsTr("Show Page 2")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SecondPage.qml"))
            }
            MenuItem {
                text: qsTr("Reload")
                onClicked: {python.getKeys();}
            }
        }

        // Tell SilicaFlickable the height of its content.
        contentHeight: column.height

        // Place our content in a Column.  The PageHeader is always placed at the top
        // of the page, followed by our content.
        Column {
            id: column

            width: page.width
            spacing: Theme.paddingLarge
            PageHeader {
                title: qsTr("Receive OATH Keys")
            }
            Label {
                id: label1
                x: Theme.horizontalPageMargin
                text: qsTr("Hello Sailors")
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                width: parent.width
            }
            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                anchors {
                            left: parent.left
                            right: parent.right
                            margins: Theme.paddingLarge
                        }

                Label {
                    id: label2
                    text: qsTr("Hello Sailors")
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    width: parent.width / 2
                }
                Label {
                    id: label3
                    text: qsTr("Hello Sailors")
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    width: parent.width / 2
                }
            }
        }
    }

    Python {
       id: python
       Component.onCompleted: {
           addImportPath(Qt.resolvedUrl('.'));

           setHandler('Key', function(val) {
               label1.text = val;
               keys = JSON.parse(val);
               label2.text = keys[0];
           });

           importModule('ykcon', function () {});
        }


       function getKeys() {
           call('ykcon.ykcon.getKeys', [], function() {});
       }

       onError: {
           // when an exception is raised, this error handler will be called
           console.log('python error: ' + traceback);
       }

       onReceived: {
           // asychronous messages from Python arrive here
           // in Python, this can be accomplished via pyotherside.send()
           console.log('got message from python: ' + data);
       }
    }
}
