import 'package:flutter/material.dart';

PreferredSizeWidget buildBlueLightAppBar({
  required String title,
  required VoidCallback onProfileTap,
}) {
  return AppBar(
    toolbarHeight: 82,
    elevation: 0,
    backgroundColor: Colors.transparent,
    flexibleSpace: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Color(0xFF0D3E7B),
                Color(0xFF1D73CF),
                Color(0xFF31A6F1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          right: -30,
          top: -20,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
    titleSpacing: 18,
    title: Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.lightbulb_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 14),
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.15),
          ),
          icon: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          onPressed: onProfileTap,
        ),
      ),
    ],
  );
}
