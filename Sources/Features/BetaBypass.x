// Bypass the "It's time to update Instagram Beta" gate.
//
// Beta/TestFlight builds show a blocking update screen at launch. Regram and
// similar tweaks hook whatever presents it and skip it; on a clean build the
// screen returns. This feature does the same with our own hook — but it needs
// the exact class/method that presents the screen, which varies by version.
//
// TO COMPLETE: enable Developer Logging, relaunch, and read the console or the
// classes.log file (Library/Application Support/UNKNW/classes.log). The view
// controller that appears for the beta screen is the one to hook here, e.g.:
//
//   %hook IGBetaUpdateViewController        // <- real name from the log
//   - (void)viewDidAppear:(BOOL)animated {
//       // dismiss / pop instead of showing it
//       [self dismissViewControllerAnimated:NO completion:nil];
//   }
//   %end
//
// (Alternatively hook the method that decides the build is expired and return
// the "up to date" result.)

#import "../UNKNW.h"

%group UNKNWBetaBypass

// TODO: %hook the beta-update gate VC/method once its name is known.

%end

void UNKNWInitBetaBypass(void) {
    %init(UNKNWBetaBypass);
}
