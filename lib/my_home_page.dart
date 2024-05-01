import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gemini_maths_app/api_settings.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  XFile? _image;
  String _responseBody = "";

  String customPrompt = "";
  bool isSending = false;

  TextEditingController tfControler = TextEditingController();
  _openCamera() {
    if (_image == null) {
      getImageFromCamera();
    }
  }

  Future<void> getImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      ImageCropper imageCropper = ImageCropper();
      final croppedImage = await imageCropper.cropImage(
        sourcePath: image.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9
        ],
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Cropper',
              toolbarColor: Colors.deepOrange,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false),
          IOSUiSettings(
            title: 'Cropper',
          ),
          WebUiSettings(
            context: context,
          ),
        ],
      );

      setState(() {
        _image = croppedImage != null ? XFile(croppedImage.path) : null;
      });
    }
  }

  Future<void> sendImage(XFile? imageFile) async {
    if (imageFile == null) return;
    setState(() {
      isSending = true;
    });
    String base64Image = base64Encode(File(imageFile.path).readAsBytesSync());
    String requestBody = json.encode({
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": customPrompt == ""
                  ? "Solve this maths function and write step by step details and the reason behind that step"
                  : customPrompt
            },
            {
              "inlineData": {"mimeType": "image/jpeg", "data": base64Image}
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 1,
        "topK": 0,
        "topP": 0.95,
        "maxOutputTokens": 8192,
        "stopSequences": []
      },
      "safetySettings": [
        {
          "category": "HARM_CATEGORY_HARASSMENT",
          "threshold": "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          "category": "HARM_CATEGORY_HATE_SPEECH",
          "threshold": "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "threshold": "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
          "threshold": "BLOCK_MEDIUM_AND_ABOVE"
        }
      ]
    });
    http.Response response = await http.post(Uri.parse(ApiSettings.apiUrl),
        headers: {"Content-Type": "application/json"}, body: requestBody);

    if (response.statusCode == 200) {
      Map<String, dynamic> jsonBody = json.decode(response.body);
      setState(() {
        _responseBody =
            jsonBody["candidates"][0]["content"]["parts"][0]["text"];
        isSending = false;
      });
    } else {
      setState(() {
        isSending = false;
      });

      print(response.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade500,
        centerTitle: true,
        title: Text(
          "Gemini AI",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
              onPressed: () {
                setState(() {
                  _image = null;
                  _responseBody = "";

                  tfControler.text = "";
                  isSending = false;
                });
              },
              icon: Icon(
                Icons.refresh,
                color: Colors.white,
              ))
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _image == null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("No Image is selected"),
                      )
                    : Image.file(File(_image!.path)),
                SizedBox(
                  height: 10,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                        hintText: "Take a photo and write a question.",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8))),
                    controller: tfControler,
                    onChanged: (value) => customPrompt = value,
                  ),
                ),
                SizedBox(
                  height: 25,
                ),
                Container(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    _responseBody,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          if (isSending)
            Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.grey.shade500,
        onPressed: () {
          _image == null ? _openCamera() : sendImage(_image);
        },
        tooltip: _image == null ? "Pick Image" : "Send Image",
        child: Icon(
          _image == null ? Icons.camera_alt : Icons.send,
          color: Colors.white,
        ),
      ),
    );
  }
}
