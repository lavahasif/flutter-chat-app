import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_app/ChatMessageListItem.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

final googleSignIn = new GoogleSignIn();

final analytics = new FirebaseAnalytics();
final auth = FirebaseAuth.instance;
var currentUserEmail;
var _scaffoldContext;

class ChatScreen extends StatefulWidget {
  @override
  ChatScreenState createState() {
    return new ChatScreenState();
  }
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textEditingController =
      new TextEditingController();
  bool _isComposingMessage = false;
  final reference = FirebaseDatabase.instance.reference().child('messages');

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("Flutter Chat App"),
          elevation:
              Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
          actions: <Widget>[
            new IconButton(
                icon: new Icon(Icons.exit_to_app), onPressed: _signOut)
          ],
        ),
        body: new Container(
          child: new Column(
            children: <Widget>[
              new Flexible(
                child: new FirebaseAnimatedList(
                  query: reference,
                  padding: const EdgeInsets.all(8.0),
                  reverse: true,
                  sort: (a, b) => b.key.compareTo(a.key),
                  //comparing timestamp of messages to check which one would appear first
                  itemBuilder: (_, DataSnapshot messageSnapshot,
                      Animation<double> animation, int index) {
                    return new ChatMessageListItem(
                      messageSnapshot: messageSnapshot,
                      animation: animation,
                    );
                  },
                ),
              ),
              new Divider(height: 1.0),
              new Container(
                decoration:
                    new BoxDecoration(color: Theme.of(context).cardColor),
                child: _buildTextComposer(),
              ),
              new Builder(builder: (BuildContext context) {
                _scaffoldContext = context;
                return new Container(width: 0.0, height: 0.0);
              })
            ],
          ),
          decoration: Theme.of(context).platform == TargetPlatform.iOS
              ? new BoxDecoration(
                  border: new Border(
                      top: new BorderSide(
                  color: Colors.grey[200],
                )))
              : null,
        ));
  }

  CupertinoButton getIOSSendButton() {
    return new CupertinoButton(
      child: new Text("Send"),
      onPressed: _isComposingMessage
          ? () => _textMessageSubmitted(_textEditingController.text)
          : null,
    );
  }

  IconButton getDefaultSendButton() {
    return new IconButton(
      icon: new Icon(Icons.send),
      onPressed: _isComposingMessage
          ? () => _textMessageSubmitted(_textEditingController.text)
          : null,
    );
  }

  Widget _buildTextComposer() {
    return new IconTheme(
        data: new IconThemeData(
          color: _isComposingMessage
              ? Theme.of(context).accentColor
              : Theme.of(context).disabledColor,
        ),
        child: new Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: new Row(
            children: <Widget>[
              new Container(
                margin: new EdgeInsets.symmetric(horizontal: 4.0),
                child: new IconButton(
                    icon: new Icon(
                      Icons.photo_camera,
                      color: Theme.of(context).accentColor,
                    ),
                    onPressed: () async {
                      await _handleSignIn();
                      File imageFile = await ImagePicker.pickImage(
                          source: null);
                      int timestamp = new DateTime.now().millisecondsSinceEpoch;
                      StorageReference storageReference = FirebaseStorage
                          .instance
                          .ref()
                          .child("img_" + timestamp.toString() + ".jpg");
                      StorageUploadTask uploadTask =
                          storageReference.put(imageFile);
                      var downloadUrl = (await uploadTask.onComplete).ref
                          .getDownloadURL();
                      _sendMessage(
                          messageText: null, imageUrl: downloadUrl.toString());
                    }),
              ),
              new Flexible(
                child: new TextField(
                  controller: _textEditingController,
                  onChanged: (String messageText) {
                    setState(() {
                      _isComposingMessage = messageText.length > 0;
                    });
                  },
                  onSubmitted: _textMessageSubmitted,
                  decoration:
                      new InputDecoration.collapsed(hintText: "Send a message"),
                ),
              ),
              new Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? getIOSSendButton()
                    : getDefaultSendButton(),
              ),
            ],
          ),
        ));
  }

  Future<Null> _textMessageSubmitted(String text) async {
    _textEditingController.clear();

    setState(() {
      _isComposingMessage = false;
    });

    await _ensureLoggedIn();
    _sendMessage(messageText: text, imageUrl: null);
  }

  void _sendMessage({String messageText, String imageUrl}) {
    reference.push().set({
      'text': messageText,
      'email': googleSignIn.currentUser.email,
      'imageUrl': imageUrl,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl,
    });

    analytics.logEvent(name: 'send_message');
  }

  Future<Null> _ensureLoggedIn() async {
    GoogleSignInAccount signedInUser = googleSignIn.currentUser;
    if (signedInUser == null)
      signedInUser = await googleSignIn.signInSilently();
    if (signedInUser == null) {
      await googleSignIn.signIn();
      analytics.logLogin();
    }

    currentUserEmail = googleSignIn.currentUser.email;

    if (await auth.currentUser() == null) {
//      GoogleSignInAuthentication credentials =
//          await signedInUser.authentication;
//      final AuthCredential credential = GoogleAuthProvider.getCredential(
//        accessToken: credentials.accessToken,
//        idToken: credentials.idToken,
//      );
////      final FirebaseUser user = await auth.signInWithCredential(credential)
//      final FirebaseUser currentUser = await auth.currentUser();
////      final FirebaseUser currentUser = await auth.currentUser();
////      await auth.signInWithCredential(credentials);
      _handleSignIn();
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<FirebaseUser> _handleSignIn() async {
    final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
    final GoogleSignInAuthentication googleAuth = await googleUser
        .authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final FirebaseUser user = (await _auth.signInWithCredential(credential))
        .user;
    print("signed in " + user.displayName);
    _handleSignIn()
        .then((FirebaseUser user) => print(user))
        .catchError((e) => print(e));
//    final FirebaseUser user = (await _auth.createUserWithEmailAndPassword(
//      email: 'an email',
//      password: 'a password',
//    ))
//        .user;
    return user;
  }


  Future _signOut() async {
    await auth.signOut();
    googleSignIn.signOut();
    Scaffold
        .of(_scaffoldContext)
        .showSnackBar(new SnackBar(content: new Text('User logged out')));
  }
}