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

        header: PageHeader {
            title: qsTr("YUBIKEY OATH TOTP Keys")
        }

        /*
        ViewPlaceholder {
            enabled: (keysList.populated && keysList.count === 0)
            text: "No Keys"
            hintText: "YubiKey not connected or no OATH Keys?"
        }
        */

        // PullDownMenu and PushUpMenu must be declared in SilicaFlickable, SilicaListView or SilicaGridView
        PullDownMenu {
            MenuItem {
                text: qsTr("Toggel allow key deletion")
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
                text: qsTr("Reload")
                onClicked: {
                    refresh_issued = true;
                    python.getKeys();
                }
            }

        }

        delegate: ListItem {
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
                spacing: Theme.paddingMedium

                anchors {
                    left: parent.left
                    right: parent.right
                    margins: Theme.paddingLarge
                }

                Label {
                    text: model.cred['id']
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    width: parent.width * 3 / 4
                }
                Label {
                    text: model.code['value']
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    wrapMode: Text.Wrap
                    width: parent.width * 1 / 4
                }
            }
        }
        VerticalScrollDecorator {}

        ProgressBar {
            id: codeElapsed
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: Theme.paddingSmall
            }

            width:  parent.width
            minimumValue: 0
            maximumValue: 100

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
                        codeElapsed.value = 0;
                        python.getKeys();
                    }
                }
                running: Qt.application.active
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
