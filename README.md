
# Scene Detective

Scene Detective combines FFMPEG's blackdetect and silencedetect functions (as well as some additional logic) to detect chapters/scene breaks in pieces of content and write them to your video file

## Requirements
- bash
- grep
- mkvpropedit
- ffmpeg

I've only tested this on a Windows machine, so I'll describe my process below.

1. Install:
- bash from https://gitforwindows.org/ (make sure to check off adding it to the context menu)
- grep from https://gnuwin32.sourceforge.net/packages/grep.htm (I chose "Complete package, except sources)
- mkvpropedit from https://mkvtoolnix.download/downloads.html (It installs with MKVToolNix)
- FFMPEG from https://ffmpeg.org/download.html (Unzip to your desired install location)
  
2. Add the "bin" subdirectory for FFMPEG and grep to the "path" environment variable on Windows. For instructions on adding environment variables, see https://learn.microsoft.com/en-us/previous-versions/office/developer/sharepoint-2010/ee537574(v=office.14)

3. Add the main directory for MKVToolNix to the "path" environment variable

4. Place scenedetect.sh in the same directory as the file being processed (if a single file) or the parent directory of the folder being processed (if a batch file)

## Usage
To run the script:

1.  Right click in the directory that contains the script file and select "Git Bash here"

2.  Run the command:
```bash scenedetect.sh [flags] [file/foldername]```

Replace ```[flags]``` with any optional flags being used (see below) and ```[file/foldername]``` with either the name of your file or folder that is being processed.

**Important Note: Only MKV files are currently supported. If your file/foldername includes spaces (and probably special characters) it MUST be encapsulated in quotation marks (ex:"filename")**

If you are batch processing files, the terminal window will alert you of any files that deviated from the most common number of chapters in the batch being processed.

## Optional Flags
The following optional flags are currently supported. They must be added to the command **BEFORE** your file/foldername and after scenedetect.sh. They follow the following syntax ```-[flag] [value]``` (ex: ```-a vlq```)
```
-v      sets the video quality, accepts: lq, vlq, vvlq, and hq
-a      sets the audio quality, accepts: lq, vlq, vvlq, and hq
-t      sets the content type, accepts: L
-d      sets the minimum duration for a break, accepts a value in seconds (ex: 240)
-x      sets the maximum duration for a break, accepts a value in seconds (ex: 240)
-m      sets the mode, only accepts: debug
-e      sets the end of the "intro" for the currently processing file(s), accepts a value in seconds (ex: 240)
-b      adjustments logic checks for breaks, only accepts "short"
-s      adjusts the starting timecode for chapters to be written, accepts a value in seconds (ex: 240)
```

### Uses for Flags
#### Video and Audio Quality Flags
The video and audio quality flags (```-a``` and ```-v```) are best used when processing older content that is of poorer quality. This can include (but is not limited to):
- content that never fades to true black
- content that has static
- content that has a constant audio hiss
The worse the quality of content, the lower you should set these flags, with the lowest option being ```vvlq``` (Very Very Low Quality)

You can also utilize these flags to speed up processing times with high quality content that has clear and distinct breaks by setting these flags to ```hq```, but there may be neglibile gains.

#### Content Type Flag
The content type flag is used to help speed up processing times for Live Action content by using a slightly different set of paramaters than the default settings.

#### Duration Flags
The duration flags are used to exclude breaks that are greater than or less than the values provided (depening on which flag is being used). This can help eliminate false positives that could be caused by longer dark scenes in content being processed or short periods of darkness that were incorrectly detected

#### Mode Flag
This flag can be added to provide more info on the scenes that are being found. It provides the time in seconds of the start and end of the blackdetect and silencedetect period as well as what percentage of each's runtime overlaps the other. This can be helpful for tweaking other flags.

#### End of Intro Flag
This flag can be used to adjust when the end of an intro is for a video or series of videos. By default, this value is 240. Scenes detected before this timecode will be written after 59 seconds of runtime, scenes detected after will be written after 3.5 minutes of runtime. The default values allow a scene to be added at the start and end of an intro and also help to prevent false postives by searching for a better match for 3.5 minutes of runtime before writing the scene.

If you want a scene on only one side of an intro, I recommend trying ```-e 0```.

#### Breaks Flag
This flag currently only accepts the option ```short```. This flag should only be used when a piece of content has very short scene breaks. **Note: If there are 0 black frames or silences, this will not help to correct that**

#### Starting Time Flag
This flag can be used to adjust the starting timecode that chapters will be written. Any matches found prior to the timecode given will be discarded and not written as chapters. This can be helpful for avoiding writing *any* chapters for an intro.
