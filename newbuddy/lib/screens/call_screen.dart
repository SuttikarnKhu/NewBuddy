import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../constants/app_config.dart';

class CallScreen extends StatefulWidget {
  final String callID;
  final String userName;

  const CallScreen({super.key, required this.callID, required this.userName});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    final userID = DateTime.now().millisecondsSinceEpoch.toString();

      return Scaffold(
        appBar: AppBar(
          title: Text('Call: ${widget.callID}'),
        ),
        body: SafeArea(
          bottom: true,
          child: Builder(builder: (context) {
            // Use MediaQuery to compute an extra bottom inset so the call
            // controls (hang-up etc.) sit above system navigation bars.
            final bottomInset = MediaQuery.of(context).viewPadding.bottom;
            // Add an extra 12-24 px above the inset for better separation.
            final extra = 24.0;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset + extra),
              child: Stack(
                children: [
                  // The prebuilt call UI fills the available space.
                  ZegoUIKitPrebuiltCall(
                    appID: AppConfig.appID,
                    appSign: AppConfig.appSign,
                    userID: userID,
                    userName: widget.userName,
                    callID: widget.callID,
                    config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
                  ),

                  // DEBUG overlay: a small semi-transparent badge positioned
                  // at the computed inset so you can visually verify the
                  // padding has taken effect. Remove this block when done.
                  Positioned(
                    right: 16,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6.0, horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        'PAD ${bottomInset.toStringAsFixed(0)}+${extra.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  // Custom overlayed control bar so the hang-up button is
                  // always visible even if the prebuilt UI positions its
                  // controls at the very bottom.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomInset + 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hang-up button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(18),
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () {
                            // Simple hang-up behaviour: pop the screen. The
                            // prebuilt call widget will be disposed and the
                            // SDK should leave the room. If you need to run
                            // cleanup before leaving, add it here.
                            Navigator.of(context).pop();
                          },
                          child: const Icon(Icons.call_end, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      );
  }
}
