import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mylocation_http/mylocation.dart';

class MyLocationScreen extends StatefulWidget {
  const MyLocationScreen({super.key});

  @override
  State<MyLocationScreen> createState() => _MyLocationScreenState();
}

class _MyLocationScreenState extends State<MyLocationScreen> {
  List<MyLocation> myLocation = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Locations'),
        centerTitle: true,
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            onPressed: () {
              searchLocation();
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Center(
        child: myLocation.isEmpty
            ? Text("No Data Available")
            : ListView.builder(
                itemCount: myLocation.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: SizedBox(
                        width: 100,
                        child: Image.network(
                          myLocation[index].imageUrl.toString(),
                          cacheWidth: 100,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 50, color: Colors.red),
                        ),
                      ),
                      title: Text(myLocation[index].name.toString()),
                      subtitle: Text(myLocation[index].state.toString()),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void searchLocation() {
    http.get(Uri.parse('https://slumberjer.com/teaching/a252/api.php')).then((
      response,
    ) {
      if (response.statusCode == 200) {
        var jsonArray = jsonDecode(response.body);
        myLocation.clear();
        int i = 0;
        for (var item in jsonArray['data']['results']) {
          myLocation.add(MyLocation.fromJson(item));
          print(myLocation[i].name);
          i++;
        }
        setState(() {});
        // print(jsonArray['data']['total']);
      }
      // log(response.body);
    });
  }
}
