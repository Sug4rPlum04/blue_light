import 'package:flutter/material.dart';

const FloatingActionButtonLocation blueLightFabLocation =
    FloatingActionButtonLocation.centerDocked;

class _CenteredCircularNotchedRectangle extends NotchedShape {
  const _CenteredCircularNotchedRectangle();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) {
      return Path()..addRect(host);
    }
    final Rect centeredGuest = Rect.fromCenter(
      center: Offset(host.center.dx, guest.center.dy),
      width: guest.width,
      height: guest.height,
    );
    return const CircularNotchedRectangle().getOuterPath(host, centeredGuest);
  }
}

class BlueLightTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BlueLightTopBar({
    super.key,
    required this.title,
    required this.onProfileTap,
    this.onEmergencyTap,
  });

  final String title;
  final VoidCallback onProfileTap;
  final VoidCallback? onEmergencyTap;

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 84,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFF09386F),
                  Color(0xFF0F5DAF),
                  Color(0xFF1799E7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            left: -30,
            top: -34,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -24,
            bottom: -44,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 1,
              margin: const EdgeInsets.only(left: 16, right: 16),
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
      titleSpacing: 16,
      title: Row(
        children: <Widget>[
          blueLightBrandMark(),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        if (onEmergencyTap != null)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: InkWell(
              onTap: onEmergencyTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6A7A7).withOpacity(0.28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.emergency_share_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 14, top: 2),
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
      ],
    );
  }
}

Widget blueLightBrandMark({double size = 34, Color iconColor = Colors.white}) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: size * 0.76,
          height: size * 0.76,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                Color(0x66D6F2FF),
                Color(0x00D6F2FF),
              ],
            ),
          ),
        ),
        Icon(
          Icons.wb_incandescent_rounded,
          color: iconColor,
          size: size * 0.65,
        ),
        Positioned(
          right: size * 0.15,
          top: size * 0.15,
          child: Container(
            width: size * 0.14,
            height: size * 0.14,
            decoration: const BoxDecoration(
              color: Color(0xFFD6F2FF),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class BlueLightBottomNav extends StatelessWidget {
  const BlueLightBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const List<IconData> icons = <IconData>[
      Icons.home_rounded,
      Icons.location_on_rounded,
      Icons.chat_rounded,
      Icons.people_alt_rounded,
    ];
    const List<String> labels = <String>['Home', 'Map', 'Messages', 'Friends'];

    Widget navCell(int index) {
      final bool isActive = currentIndex == index;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icons[index],
                  color: Colors.white,
                  size: isActive ? 22 : 20,
                ),
                const SizedBox(height: 1),
                Text(
                  labels[index],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.8,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: const BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x332C6CAB),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BottomAppBar(
          color: const Color(0xFF176EC2),
          elevation: 0,
          shape: const _CenteredCircularNotchedRectangle(),
          notchMargin: 7,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: <Widget>[
                  navCell(0),
                  navCell(1),
                  const SizedBox(width: 74),
                  navCell(2),
                  navCell(3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget buildBlueLightFab(VoidCallback onPressed) {
  return Container(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: <Color>[
          Color(0xFF27A6F6),
          Color(0xFF1386DE),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Color(0x4438A0EA),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
    ),
  );
}
