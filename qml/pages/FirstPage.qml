import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5

Page {
    id: page

    property var keys
    property var refresh_issued
    property ListModel keysList: ListModel{}
    property int editorStyle: TextEditor.UnderlineBackground

    property var keyName;
    property var secret;
    property string hashAlgo: 'SHA1';
    property string issuer: '';

    // The effective value will be restricted by ApplicationWindow.allowedOrientations
    allowedOrientations: Orientation.All

    onStatusChanged: {
        if ((status == Component.Ready))
        {
            python.getKeys();
            refresh_issued = false;
        }
    }

    // To enable PullDownMenu, place our content in a SilicaFlickable
    SilicaFlickable {
        anchors.fill: parent

        // PullDownMenu and PushUpMenu must be declared in SilicaFlickable, SilicaListView or SilicaGridView
        PullDownMenu {
//            MenuItem {
//                text: qsTr("Show Page 2")
//                onClicked: {
//                    console.log(new Date().getTime())
//                    console.log(keys[0]['code']['valid_to']*1000);
//                    console.log(keys[0]['code']['valid_to']*1000 - new Date().getTime());
//                    console.log((keys[0]['code']['valid_to'] - keys[0]['code']['valid_from']));
//                    console.log((keys[0]['code']['valid_to'] - new Date().getTime()/1000)/ (keys[0]['code']['valid_to'] - keys[0]['code']['valid_from']));
//                }
//            }
            MenuItem {
                text: qsTr("Add Key")
                onClicked: {
                    var obj = pageStack.push(newKeyDialog)
                    obj.accepted.connect(function() {

                    })
                }
            }
            MenuItem {
                text: qsTr("Reload")
                onClicked: {
                    refresh_issued = true;
                    python.getKeys();
                }
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
                title: qsTr("YUBIKEY OATH TOTP Keys")
            }

            ProgressBar {
                id: codeElapsed
                anchors {
                    left: parent.left
                    right: parent.right
                    margins: Theme.paddingSmall
                }
                //width: Theme.iconSizeMedium
                //height: Theme.iconSizeMedium
                width:  parent.width
                minimumValue: 0
                maximumValue: 100
                //valueText: value
                //label: "Progress"
                Timer {
                    id: refresh_timer
                    interval: 100
                    repeat: true
                    onTriggered: {
                        try{
                            codeElapsed.value = 100*((keys[0]['code']['valid_to'] - new Date().getTime()/1000)/ (keys[0]['code']['valid_to'] - keys[0]['code']['valid_from']));
                            if (codeElapsed.value <= 0 && refresh_issued === false) {
                                refresh_issued = true;
                                python.getKeys();
                        }
                        } catch (e) {
                            console.log('error?')
                            codeElapsed = 0;
                            python.getKeys();
                        }
                    }
                    running: Qt.application.active
                }
            }

            Repeater {

                model: keysList

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: Theme.paddingLarge
                    }

                    Label {
                        text: model.cred['id']
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        width: parent.width * 3 / 4
                    }
                    Label {
                        text: model.code['value']
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        wrapMode: Text.Wrap
                        width: parent.width * 1 / 4
                    }
                }
            }


//            Label {
//                id: label1
//                x: Theme.horizontalPageMargin
//                text: qsTr("Hello Sailors")
//                color: Theme.secondaryHighlightColor
//                font.pixelSize: Theme.fontSizeSmall
//                wrapMode: Text.Wrap
//                width: parent.width
//            }

        }
    }

    Python {
       id: python
       Component.onCompleted: {
           addImportPath(Qt.resolvedUrl('.'));

           setHandler('keys', function(val) {
               keysList.clear();
               keys = JSON.parse(val);
               for (var s_key in keys) {
                   keysList.append({'cred': keys[s_key]['cred'], 'code': keys[s_key]['code']})
               }
               refresh_timer.start()
               refresh_issued = false
           });

           setHandler('no_key', function(val) {
               refresh_timer.stop()
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

    Component {
             id: newKeyDialog
             Dialog {

                 onAccepted: {

                     keyName = nameField.text
                     secret = secretField.text
                     hashAlgo = cbxHashAlgo.currentItem.text
                     issuer = issuerField.text

                     refresh_issued = true;
                     python.call('ykcon.ykcon.deleteKey', [keyName, secret, hashAlgo, issuer], function() {});
                     python.getKeys();
                 }

                 Column {
                     id: column
                     width: parent.width

                     DialogHeader {
                         id: header
                         title: "Add OATH TOTP Key"
                     }

                     Repeater {

                         model: keysList

                         Row {
                             width: parent.width
                             spacing: Theme.paddingMedium

                             anchors {
                                 left: parent.left
                                 right: parent.right
                                 margins: Theme.paddingLarge
                             }

                             Label {
                                 text: model.cred['id']
                                 color: Theme.secondaryHighlightColor
                                 wrapMode: Text.Wrap
                                 width: parent.width
                             }
                         }
                     }
                }
            }
        }


    Component {
             id: deleteKeyDialog
             Dialog {

                 onAccepted: {
                     keyName = nameField.text
                     refresh_issued = true;
                     python.call('ykcon.ykcon.deleteKey', keyName, function() {});
                     python.getKeys();
                 }

                 Column {
                     id: column
                     width: parent.width

                     DialogHeader {
                         id: header
                         title: "Delete Key"
                     }

                     TextField {
                         id: nameField
                         focus: true
                         label: "Name"
                         EnterKey.iconSource: "image://theme/icon-m-enter-next"
                         EnterKey.onClicked: secretField.focus = true

                         backgroundStyle: page.editorStyle
                     }

                     TextField {
                         id: secretField
                         focus: true
                         label: "Secret"
                         EnterKey.iconSource: "image://theme/icon-m-enter-next"
                         EnterKey.onClicked: issuerField.focus = true

                         backgroundStyle: page.editorStyle
                     }

                     SectionHeader {
                         text: "Advanced (optional)"
                     }

                     TextField {
                         id: issuerField
                         focus: true
                         label: "Issuer"
                         EnterKey.iconSource: "image://theme/icon-m-enter-close"
                         EnterKey.onClicked: focus = false

                         backgroundStyle: page.editorStyle
                     }

                     ComboBox {
                         id: cbxHashAlgo
                         label: "Hash Algorythm:"
                         width: parent.width

                         menu: ContextMenu {
                             MenuItem { text: "SHA1" }
                             MenuItem { text: "SHA256" }
                             MenuItem { text: "SHA512" }
                         }
                     }
                }
            }
        }
}
