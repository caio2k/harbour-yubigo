import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5

Page {
    id: page

    property var keys
    property var refresh_issued
    property ListModel keysList: ListModel{}
    property int editorStyle: TextEditor.UnderlineBackground
    property bool allow_deletion: false

    property var keyName
    property var secret
    property string hashAlgo: 'SHA1'
    property string issuer: ''

    property double seconds_countdown: 0
    property double seconds_warning: 30

    // The effective value will be restricted by ApplicationWindow.allowedOrientations
    allowedOrientations: Orientation.All

    onStatusChanged: {
        if ((status == Component.Ready))
        {
            refresh_issued = true;
            python.getKeys();
        }
    }

    // To enable PullDownMenu, place our content in a SilicaFlickable
    property bool deletingItems

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: keysList

        header: Row {
            id: headerRow
            height: page.isLandscape ? Theme.itemSizeSmall : Theme.itemSizeLarge
            width: parent.width
            layoutDirection: Qt.RightToLeft
            Label {
              id: header
              width: Math.min(implicitWidth, parent.width - Theme.horizontalPageMargin - Theme.horizontalPageMargin)
              truncationMode: TruncationMode.Fade

              // color should indicate if interactive
              color: Theme.primaryColor

              anchors {
                  top: parent.top
                  topMargin: Theme.paddingLarge
                  //right: parent.right
                  rightMargin: Theme.horizontalPageMargin
              }
              font {
                  pixelSize: Theme.fontSizeLarge
                  family: Theme.fontFamilyHeading
              }
              text: "Yubigo"
            }
            ProgressBar {
              id: codeElapsed
              anchors.topMargin: Theme.paddingLarge * 1.15
              anchors.top: parent.top
              //workaround to get big enough bar... but row complains about it
              anchors.left: parent.left
              anchors.right: header.left
              minimumValue: 0
              maximumValue: 100
              value: seconds_countdown
              indeterminate: seconds_countdown <= 0
              highlighted: seconds_countdown > seconds_warning
              visible: listView.count > 0
            }

        }

        Timer {
            id: refresh_timer
            interval: 100
            repeat: true
            onTriggered: {
                try{
                    seconds_countdown = 100*((keys[0]['code']['valid_to'] - new Date().getTime()/1000)/ (keys[0]['code']['valid_to'] - keys[0]['code']['valid_from']));
                    if (seconds_countdown <= 0 && refresh_issued === false) {
                        refresh_issued = true;
                        python.getKeys();
                }
                } catch (e) {
                    seconds_countdown = 0;
                    python.getKeys();
                }
            }
            running: Qt.application.active
        }

        ViewPlaceholder {
            enabled: listView.count === 0
            text: qsTr("No Keys to show")
            hintText: qsTr("Insert a YubiKey with OAUTH keys and select Refresh in the pull down menu.")
        }

        // PullDownMenu and PushUpMenu must be declared in SilicaFlickable, SilicaListView or SilicaGridView
        PullDownMenu {
            MenuItem {
                text: qsTr("Toggle allow key deletion")
                onClicked: {
                    if (allow_deletion === true) allow_deletion = false
                    else allow_deletion = true
                }
            }
            MenuItem {
                text: qsTr("Add Key")
                onClicked: {
                    var obj = pageStack.push(newKeyDialog)
                    obj.accepted.connect(function() {

                    })
                }
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    refresh_issued = true;
                    python.getKeys();
                }
            }

        }

        delegate: ListItem {
            id: listItem
            contentHeight: visible ? Theme.itemSizeLarge: 0
            width: parent.width

            function remove() {
                remorseDelete(function() {
                    refresh_issued = true;
                    python.call('ykcon.ykcon.deleteKey', [model.cred['id']], function() {});
                    python.getKeys();
                })

            }

            onClicked: {
                if (!menuOpen && pageStack.depth == 2) {
                    pageStack.animatorPush(Qt.resolvedUrl("ListPage.qml"))
                }
            }

            ListView.onRemove: animateRemoval()
            opacity: enabled ? 1.0 : 0.0
            Behavior on opacity { FadeAnimator {}}

            menu: Component {
                ContextMenu {
                    MenuItem {
                        text: qsTr("To clipboard")
                        onClicked: Clipboard.text = model.code['value']
                    }
                    MenuItem {
                        enabled: allow_deletion
                        text: qsTr("Delete")
                        onClicked: remove()
                    }
                }
            }
            Row {
                width: parent.width
                spacing: Theme.paddingSmall
                layoutDirection: Qt.RightToLeft
                height: page.isLandscape ? Theme.itemSizeSmall : Theme.itemSizeLarge
                anchors.margins: Theme.paddingMedium


                Label {
                    id: valueLabel
                    text: model.code['value']
                    color: seconds_countdown <= seconds_warning ? Theme.secondaryColor : Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                    height: parent.height
                    verticalAlignment: "AlignVCenter"
                    wrapMode: Text.Wrap
//                    width: parent.width * 1 / 4
                }
                Column {
                    width: parent.width - valueLabel.width
//                    width: Math.min(implicitWidth, parent.width - Theme.horizontalPageMargin - Theme.horizontalPageMargin)

                    Label {
                        text: model.cred['id'].toString().split(':')[0]
                        width: parent.width - x
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    Label {
                        text: model.cred['id'].toString().split(':')[1] === undefined ? '' : model.cred['id'].toString().split(':')[1]
                        truncationMode: TruncationMode.Fade
                        visible: text != 'undefined'
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            Python {
               id: python
               Component.onCompleted: {
                   addImportPath(Qt.resolvedUrl('.'));

                   setHandler('keys', function(val) {
                       keys = JSON.parse(val);
                       keysList.clear();
                       for (var s_key in keys) {
                           keysList.append({'cred': keys[s_key]['cred'], 'code': keys[s_key]['code']})
                       }
                       refresh_timer.start()
                       refresh_issued = false
                   });

                   setHandler('no_key', function(val) {
                       headerRow.refresh_timer.stop()
                   });

                   setHandler('del:key_not_found', function(val) {
                       console.log("del:key_not_found")
                   });

                   setHandler('del:succ', function(val) {
                       console.log("del:succ")
                   });

                   setHandler('del:not_unique', function(val) {
                       console.log("del:not_unique")
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
        VerticalScrollDecorator {}


        Python {
           id: python
           Component.onCompleted: {
               addImportPath(Qt.resolvedUrl('.'));

               setHandler('keys', function(val) {
                   keys = JSON.parse(val);
                   keysList.clear();
                   for (var s_key in keys) {
                       keysList.append({'cred': keys[s_key]['cred'], 'code': keys[s_key]['code']})
                   }
                   refresh_timer.start()
                   refresh_issued = false
               });

               setHandler('no_key', function(val) {
                   refresh_timer.stop()
               });

               setHandler('del:key_not_found', function(val) {
                   console.log("del:key_not_found")
               });

               setHandler('del:succ', function(val) {
                   console.log("del:succ")
               });

               setHandler('del:not_unique', function(val) {
                   console.log("del:not_unique")
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

    Component {
         id: newKeyDialog
         Dialog {

             onAccepted: {
                 keyName = nameField.text
                 secret = secretField.text
                 hashAlgo = cbxHashAlgo.currentItem.text
                 issuer = issuerField.text

                 refresh_issued = true;
                 python.call('ykcon.ykcon.writeKey', [keyName, secret, hashAlgo, issuer], function() {});
                 python.getKeys();
             }

             Column {
                 id: column
                 width: parent.width

                 DialogHeader {
                     id: header
                     title: qsTr("Add OATH TOTP Key")
                 }

                 SectionHeader {
                     text: qsTr("Credential details")
                 }

                 TextField {
                     id: nameField
                     focus: true
                     label: qsTr("Name")
                     EnterKey.iconSource: "image://theme/icon-m-enter-next"
                     EnterKey.onClicked: secretField.focus = true

                     backgroundStyle: page.editorStyle
                 }

                 TextField {
                     id: secretField
                     focus: true
                     label: qsTr("Secret")
                     EnterKey.iconSource: "image://theme/icon-m-enter-next"
                     EnterKey.onClicked: issuerField.focus = true

                     backgroundStyle: page.editorStyle
                 }

                 SectionHeader {
                     text: qsTr("Advanced (optional)")
                 }

                 TextField {
                     id: issuerField
                     focus: true
                     label: qsTr("Issuer")
                     EnterKey.iconSource: "image://theme/icon-m-enter-close"
                     EnterKey.onClicked: focus = false

                     backgroundStyle: page.editorStyle
                 }

                 ComboBox {
                     id: cbxHashAlgo
                     label: qsTr("Hash Algorythm:")
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
