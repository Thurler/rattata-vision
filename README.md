# Rattata Vision

Use Google's Vision API to detect text from anywhere on your screen. Use it to extract text from games, manga, or any other media that doesn't allow you to copy its text!

## Why Rattata?

RATTATA is short for "Read All The Time And Take Amphetamines", a funny image I found on an imageboard once that provided a lasting impact on how I should learn Japanese. In the spirit of easing my way into reading manga, I developed a beta version of this tool in Python and QT, and have been using it for a while. One day I decided to rewrite it in Flutter and share it with the world.

## How does it work?

The software will periodically take screenshots of your desktop screen, and upload the latest screenshot when you hit the "Recognize text" button to Google's Vision API. Google will then do their magic to automatically detect text in the image, no matter what language.

Because your desktop screen can be filled with text from irrelevant things that you don't want Google seeing, an auxiliary translucent screen is provided to limit the screenshot area. You can easily move it around and resize it as needed, to either capture an entire game window or just a manga's speech bubble.

You can tweak how often the software takes screenshots in the settings. Generally you don't want to go above 10 screenshots per second, but faster options are provided for smoother previews. You can also specify the language you're detecting, so Google doesn't accidentally think your Japanese text is Chinese, for example.

## Installation Guide

This software requires an integration with Google's Vision API. You must setup a project yourself and provide this software with your API credentials, a JSON file Google gives you when you set everything up. Here's a (possibly outdated) step-by-step:

### Extra steps for Linux users

Linux users should install `scrot` from their package manager. This is the behind-the-scenes tool that takes screenshots of your desktop screen. It is also a VERY useful tool for everyday use, so you should install it regardless.

## Contributing

If you want to help make this software better, here's a TODO list of things I think are useful but have no time or willpower to code:

- Automatically detect when there is new text in the capture area, to automatically upload the new image to Google
  - If you just upload once per second, you'll hit your free quota pretty fast!
- Integrate with a translation tool so that text is automatically translated too
  - Could be nice to remove the whole Alt+Tab in and out of a translator
- Stop using a temporary file on disc to zero disc usage - keep everything in RAM
  - This would not only speedup the application, but also prevent constant writing and reading on the user's poor disc
- Add support for MacOS devices
  - I do not have a Mac to test screenshot integrations - does `scrot` even work in MacOS?
- Add support for Android / iOS devices
  - I have no idea how to make this idea work for mobile - suggestions welcome!

If you encounter problems with the software, feel free to open an issue, and I'll try to address it whenever I have free time. Remember this is a hobby project.
