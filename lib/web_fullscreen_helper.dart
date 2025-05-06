// Only imported on web
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void enterWebFullscreen() {
  js.context.callMethod('eval', [
    '''
    var elem = document.querySelector('video');
    if (elem && elem.requestFullscreen) elem.requestFullscreen();
    else if (elem && elem.webkitRequestFullscreen) elem.webkitRequestFullscreen();
    else if (elem && elem.mozRequestFullScreen) elem.mozRequestFullScreen();
    else if (elem && elem.msRequestFullscreen) elem.msRequestFullscreen();
    '''
  ]);
}

void exitWebFullscreen() {
  js.context.callMethod('eval', [
    '''
    if (document.exitFullscreen) document.exitFullscreen();
    else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
    else if (document.mozCancelFullScreen) document.mozCancelFullScreen();
    else if (document.msExitFullscreen) document.msExitFullscreen();
    '''
  ]);
}
