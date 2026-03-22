import 'package:flutter/material.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/message.dart';
import 'package:blue_light/map.dart';
import 'package:blue_light/profile.dart';
import 'package:blue_light/add_friend.dart';
import 'package:blue_light/ui/shell_chrome.dart';

class MyFriendsPage extends StatefulWidget {
  const MyFriendsPage({super.key, required this.title});

  final String title;

  @override
  State<MyFriendsPage> createState() => _MyFriendsPageState();
}

class _MyFriendsPageState extends State<MyFriendsPage> {

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
      appBar: BlueLightTopBar(
        title: widget.title,
        onProfileTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) =>
                  const MyProfilePage(title: "Profile"),
            ),
          );
        },
      ),
      floatingActionButton: buildBlueLightFab(() {}),
      floatingActionButtonLocation: blueLightFabLocation,
      bottomNavigationBar: BlueLightBottomNav(
        currentIndex: 3,
        onTap: (int index) {
          if (index == 3) {
            return;
          }
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) => const MyHomePage(title: "Home"),
              ),
            );
            return;
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) => const MyMapPage(title: "Map"),
              ),
            );
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) =>
                  const MyMessagePage(title: "Messages"),
            ),
          );
        },
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyAddFriendsPage(title: "Discover People"),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadiusGeometry.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.person_add),
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

                  return Dismissible(
                    key: ValueKey(f["name"]),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      setState(() {
                        _friends.remove(f);
                      });
                    },
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Container(
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
                            OutlinedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text("Remove Friend"),
                                      content: Text(
                                        "Are you sure you want to remove ${f["name"]}?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _friends.remove(f);
                                            });
                                            Navigator.pop(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            "Remove",
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        )
                                      ],
                                    );
                                  },
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.lightBlue),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Remove",
                                style: TextStyle(color: Colors.lightBlue),
                              ),
                            ),
                            // OutlinedButton(
                            //   onPressed: () {
                            //     setState(() {
                            //       _friends.remove(f);
                            //     });
                            //   },
                            //   style: OutlinedButton.styleFrom(
                            //     side: const BorderSide(color: Colors.lightBlue),
                            //     shape: RoundedRectangleBorder(
                            //       borderRadius: BorderRadius.circular(12),
                            //     ),
                            //   ),
                            //   child: const Text(
                            //     "Remove",
                            //     style: TextStyle(color: Colors.lightBlue),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  );

                  // return Container(
                  //   margin: const EdgeInsets.only(bottom: 12),
                  //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(14),
                  //     boxShadow: const [
                  //       BoxShadow(
                  //         color: Colors.black12,
                  //         blurRadius: 6,
                  //         offset: Offset(0, 2),
                  //       ),
                  //     ],
                  //   ),
                  //   child: Row(
                  //     children: [
                  //       CircleAvatar(
                  //         radius: 26,
                  //         backgroundImage: NetworkImage(f["photo"]!),
                  //         backgroundColor: Colors.grey.shade200,
                  //       ),
                  //       const SizedBox(width: 12),
                  //
                  //       Expanded(
                  //         child: Text(
                  //           f["name"]!,
                  //           style: const TextStyle(
                  //             fontSize: 15,
                  //             fontWeight: FontWeight.w700,
                  //           ),
                  //         ),
                  //       ),
                  //
                  //       OutlinedButton(
                  //         onPressed: () {},
                  //         style: OutlinedButton.styleFrom(
                  //           side: const BorderSide(color: Colors.lightBlue),
                  //           shape: RoundedRectangleBorder(
                  //             borderRadius: BorderRadius.circular(12),
                  //           ),
                  //         ),
                  //         child: const Text(
                  //           "Remove",
                  //           style: TextStyle(color: Colors.lightBlue),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // );
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
