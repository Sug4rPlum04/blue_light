import 'package:flutter/material.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/friends.dart';
import 'package:blue_light/map.dart';
import 'package:blue_light/profile.dart';

class MyMessagePage extends StatefulWidget {
  const MyMessagePage({super.key, required this.title});

  final String title;

  @override
  State<MyMessagePage> createState() => _MyMessagePageState();
}

class _MyMessagePageState extends State<MyMessagePage> {

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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyProfilePage(title: "Profile"),
                  ),
                );
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
              // _navItem(icon: Icons.location_on, label: "Map", onTap: () {}),
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

              _navItem(icon: Icons.chat_rounded, label: "Messages", onTap: () {}),
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
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12)
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                        });
                      },
                      decoration: InputDecoration(
                        icon: Icon(Icons.search),
                        hintText: "Search",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {

                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadiusGeometry.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.edit_note_rounded, size: 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: filteredFriends.length,
                itemBuilder: (context, index) {
                  final f = filteredFriends[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(f["photo"]!),
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            f["name"]!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
