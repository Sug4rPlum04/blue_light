import 'package:flutter/material.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/message.dart';
import 'package:blue_light/map.dart';
import 'package:blue_light/profile.dart';
import 'package:blue_light/friends.dart';
import 'package:blue_light/ui/app_chrome.dart';

class MyAddFriendsPage extends StatefulWidget {
  const MyAddFriendsPage({super.key, required this.title});

  final String title;

  @override
  State<MyAddFriendsPage> createState() => _MyAddFriendsPageState();
}

class _MyAddFriendsPageState extends State<MyAddFriendsPage> {

  final List<Map<String, String>> _friends = List.generate(
    25,
        (i) => {
      "name": "Friend ${i + 1}",
      "photo": "https://cdn-icons-png.freepik.com/512/5400/5400308.png",
    },
  );

  // CHANGED → mutuals now show as "n mutuals"
  final List<Map<String, String>> _followRequests = List.generate(
    10,
        (i) => {
      "name": "User ${i + 1}",
      "mutuals": "${i + 2} mutuals",
      "photo": "https://cdn-icons-png.freepik.com/512/5400/5400308.png",
    },
  );

  // NEW → controls whether the full list is shown
  bool _showAllRequests = false;

  @override
  Widget build(BuildContext context) {

    // NEW → show first 5 unless expanded
    final visibleRequests = _showAllRequests
        ? _followRequests
        : _followRequests.take(3).toList();

    return Scaffold(
      appBar: buildBlueLightAppBar(
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

      // floatingActionButton: SizedBox(
      //   width: 72,
      //   height: 72,
      //   child: FloatingActionButton(
      //     onPressed: () {},
      //     backgroundColor: Colors.lightBlueAccent,
      //     shape: const CircleBorder(),
      //     elevation: 6,
      //     child: const Icon(Icons.add, color: Colors.white),
      //   ),
      // ),
      //
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      //
      // bottomNavigationBar: BottomAppBar(
      //   shape: const CircularNotchedRectangle(),
      //   notchMargin: 8,
      //   color: Colors.lightBlue,
      //   child: SizedBox(
      //     height: 70,
      //     child: Row(
      //       mainAxisAlignment: MainAxisAlignment.spaceAround,
      //       children: [
      //         _navItem(
      //           icon: Icons.home_rounded,
      //           label: "Home",
      //           onTap: () {
      //             Navigator.pushReplacement(
      //               context,
      //               MaterialPageRoute(
      //                 builder: (context) => const MyHomePage(title: "Home"),
      //               ),
      //             );
      //           },
      //         ),
      //         _navItem(
      //           icon: Icons.location_on,
      //           label: "Map",
      //           onTap: () {
      //             Navigator.pushReplacement(
      //               context,
      //               MaterialPageRoute(
      //                 builder: (context) => const MyMapPage(title: "Map"),
      //               ),
      //             );
      //           },
      //         ),
      //
      //         const SizedBox(width: 40),
      //
      //         _navItem(
      //           icon: Icons.chat_rounded,
      //           label: "Messages",
      //           onTap: () {
      //             Navigator.pushReplacement(
      //               context,
      //               MaterialPageRoute(
      //                 builder: (context) => const MyMessagePage(title: "Messages"),
      //               ),
      //             );
      //           },
      //         ),
      //
      //         // CHANGED → fixed icon
      //         _navItem(
      //           icon: Icons.people_alt_rounded,
      //           label: "Friends",
      //           onTap: () {
      //             Navigator.pushReplacement(
      //               context,
      //               MaterialPageRoute(
      //                 builder: (context) => const MyFriendsPage(title: "Friends"),
      //               ),
      //             );
      //           },
      //         ),
      //       ],
      //     ),
      //   ),
      // ),

      // BODY
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleRequests.length,
                        itemBuilder: (context, index) {
                          final request = visibleRequests[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundImage: NetworkImage(request["photo"]!),
                                  backgroundColor: Colors.grey.shade200,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request["name"]!,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        request["mutuals"]!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      height: 34,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _friends.add({
                                              "name": request["name"]!,
                                              "photo": request["photo"]!,
                                            });
                                            _followRequests.remove(request);
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.lightBlue,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text("Confirm"),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 90,
                                      height: 34,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            _followRequests.remove(request);
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.grey),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(color: Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (_followRequests.length > 3)
                      Align(
                        alignment: Alignment.centerRight, // CHANGED
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // smaller padding
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _showAllRequests = !_showAllRequests;
                            });
                          },
                          child: Text(
                            _showAllRequests ? "Show less" : "See all",
                            style: const TextStyle(
                              color: Colors.lightBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Positioned(
                left: 20,
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "Follow Requests",
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
