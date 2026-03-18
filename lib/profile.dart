import 'package:flutter/material.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/friends.dart';
import 'package:blue_light/map.dart';
import 'package:blue_light/message.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key, required this.title});

  final String title;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {

  final List<Map<String, String>> _friends = List.generate(
    25,
        (i) => {
      "name": "Friend ${i + 1}",
      "photo": "https://cdn-icons-png.freepik.com/512/5400/5400308.png",
    },
  );

  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    final filteredFriends = _friends.where((f) {
      final name = (f["name"] ?? "").toLowerCase();
      final query = _searchText.toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        toolbarHeight: 100,
        title: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
          ),
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: IconButton(
              icon: const Icon(Icons.person, color: Colors.white, size: 30),
              onPressed: () {

              },
            ),
          ),
        ],
      ),

      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          onPressed: () {

          },
          backgroundColor: Colors.lightBlueAccent,
          shape: const CircleBorder(),
          elevation: 6,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.lightBlue,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              //_navItem(icon: Icons.home_rounded, label: "Home", onTap: () {}),
              _navItem(
                icon: Icons.home_rounded,
                label: "Home",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyHomePage(title: "Home"),
                    ),
                  );
                },
              ),
              _navItem(
                icon: Icons.location_on,
                label: "Map",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyMapPage(title: "Map"),
                    ),
                  );
                },
              ),

              const SizedBox(width: 40),

              _navItem(
                icon: Icons.chat_rounded,
                label: "Messages",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyMessagePage(title: "Messages"),
                    ),
                  );
                },
              ),
              _navItem(
                icon: Icons.people_alt_rounded,
                label: "Friends",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyFriendsPage(title: "Friends"),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text (
          "profile here",
        ),
      ),
    );
  }
}

Widget _navItem({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    ),
  );
}
