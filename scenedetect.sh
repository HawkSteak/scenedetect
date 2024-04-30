#!/bin/bash
#  Create a log file with ffmpeg's blackdetect output of a file or all files in a directory.
#
# Arguments:
#   1 - Path to an mkv file
#   2 -
# Outputs:
#   Print blackdetect output to stdout
##############################
chapter_count=0

CYAN='\033[0;36m'
GREEN='\033[0;32m'
LGREEN='\033[1;32m'
RED='\033[0;31m'
NC='\033[0m'

REQUIRES="ffmpeg mkvpropedit grep"

while getopts "t:m:b:v:a:e:d:x:s:" flag;
do
    case $flag in
        t) content_type=${OPTARG};;
        m) mode=${OPTARG};;
        b) breaks=${OPTARG};;
        v) vq=${OPTARG};;
        a) aq=${OPTARG};;
        e) introEnd=${OPTARG};;
        d) minDur=${OPTARG};;
        x) maxDur=${OPTARG};;
        s) startTime=${OPTARG};;
    esac
done
shift $((OPTIND - 1))

if [[ "$content_type" = "live" ]]; then
  type="L"
  typeName="Live Action"
elif [[ "$content_type" = "anim" ]]; then
  type="A"
  typeName="Animated"
else
  type="D"
  typeName="Default"
fi;

filesArray=()
chaptersTotal=()


function blackdetect
{
    # Set elapsed time to zero and echo Start Notice
    SECONDS=0
    echo -e "Starting to process ${CYAN}$1${NC} as $typeName Content" >&2

    # Get the runtime of the file
    videoduration=$(ffprobe -threads auto -i "$1" -show_entries format=duration -v quiet -of csv="p=0")

    # Determine settings based on profile Input
    if [[ "$type" = "A" ]] || [[ "$type" = "D" ]]; then
      if [[ "$aq" = "vvlq" ]]; then
        silence_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -af "silencedetect=n=-25dB:d=0.05" -vn -f null - 2>&1 | grep -Eo '\[silencedetect.*')
      elif [[ "$aq" = "vlq" ]]; then
        silence_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -af "silencedetect=n=-35dB:d=0.05" -vn -f null - 2>&1 | grep -Eo '\[silencedetect.*')
      elif [[ "$aq" = "lq" ]]; then
        silence_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -af "silencedetect=n=-40dB:d=0.05" -vn -f null - 2>&1 | grep -Eo '\[silencedetect.*')
      elif [[ "$aq" = "hq" ]]; then
        silence_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -af "silencedetect=n=-60dB:d=0.05" -vn -f null - 2>&1 | grep -Eo '\[silencedetect.*')
      else
        silence_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -af "silencedetect=n=-45dB:d=0.05" -vn -f null - 2>&1 | grep -Eo '\[silencedetect.*')
      fi
      if [[ "$vq" = "lq" ]]; then
        black_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -vf "blackdetect=d=0.1:pix_th=0.15:pic_th=1.0" -an -f null - 2>&1 | grep -Eo '\[blackdetect.*')
      elif [[ "$vq" = "vlq" ]]; then
        black_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -vf "blackdetect=d=0.1:pix_th=0.3:pic_th=1.0" -an -f null - 2>&1 | grep -Eo '\[blackdetect.*')
      elif [[ "$vq" = "vvlq" ]]; then
        black_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -vf "blackdetect=d=0.05:pix_th=0.3:pic_th=1.0" -an -f null - 2>&1 | grep -Eo '\[blackdetect.*')
      elif [[ "$vq" = "hq" ]]; then
        black_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -vf "blackdetect=d=0.1:pix_th=0.05:pic_th=1.0" -an -f null - 2>&1 | grep -Eo '\[blackdetect.*')
      else
        black_output=$(ffmpeg -hwaccel cuda -threads auto -hide_banner -i "$1" -vf "blackdetect=d=0.1:pix_th=0.05:pic_th=1.0" -an -f null - 2>&1 | grep -Eo '\[blackdetect.*')
      fi
      #silence_output=$(ffprobe -threads auto -hide_banner -f lavfi -i "amovie='$1',silencedetect=n=-45dB:d=0.05" -select_streams a:1 -show_entries tags=lavfi.silence_start,lavfi.silence_end -of default=nw=1 2>&1 | grep '\[silencedetect @')
    #  black_output=$(ffprobe -threads auto -hide_banner -f lavfi -i "movie='$1',blackdetect=d=0.1:pix_th=0.05:pic_th=1.0" -select_streams v:1 -show_entries tags=lavfi.black_start,lavfi.black_end -of default=nw=1 2>&1 | grep '\[blackdetect @')
    elif [[ "$type" = "L" ]]; then
      silence_output=$(ffmpeg -threads auto -hwaccel cuda -hide_banner -i "$1" -af "silencedetect=n=-60dB:d=0.1" -vn -f null - 2>&1 | grep -Eo '\[silencedetect.*')
      black_output=$(ffmpeg -threads auto -hwaccel cuda -hide_banner -i "$1" -vf "blackdetect=d=0.2:pix_th=0.1:pic_th=1.0" -an -f null - 2>&1 | grep -Eo '\[blackdetect.*')
      #silence_output=$(ffprobe -threads auto -hide_banner -f lavfi -i "amovie='$1',silencedetect=n=-60dB:d=0.1" -select_streams a:1 -show_entries tags=lavfi.silence_start,lavfi.silence_end -of default=nw=1 2>&1 | grep '\[silencedetect @')
      #black_output=$(ffprobe -threads auto -hide_banner -f lavfi -i "movie='$1',blackdetect=d=0.2:pix_th=0.1:pic_th=1.0" -select_streams v:1 -show_entries tags=lavfi.black_start,lavfi.black_end -of default=nw=1 2>&1 | grep '\[blackdetect @')
    fi

    # Create empty arrays, zeroes out needed variables
    start_times=()
    end_times=()
    Vstart_times=()
    Vend_times=()

    bestMatch=0
    bestMatchDuration=0
    bestMatchAudio=0
    bestMatchText=0
    percentMatchA=0
    percentMatchV=0
    bestMatchPercentA=0
    bestMatchPercentV=0
    lastMatch=0

    # Add the first chapter at the start of the file, sets the chapter counter to 1 and Last Chapter to 0
    echo -e "CHAPTER01=00:00:00.000\nCHAPTER01NAME=Chapter 1\n"
    counter=1
    lastChapter=0
    echo -e "Found Chapter $counter at ${GREEN}[00:00:00.000]${NC}" >&2

    # Read through the silencedetect output and add the start and end times to arrays
    while read -r line1; do
        read -r line2
        sound_start_time_str=$(cut -f5 -d' ' <<< "$line1")
        sound_end_time_str=$(cut -f5 -d' ' <<< "$line2")

        sound_start=${sound_start_time_str#silence_start: }
        sound_end=${sound_end_time_str#silence_end: }

        start_times+=("$sound_start")
        end_times+=("$sound_end")
    done <<< "$silence_output"

    # Read through the blackdetect output and add the start and end as well as duration times to arrays
    while read -r line1; do
        if [ -n "$line1" ]; then
          start_time_str=$(cut -f4 -d' ' <<< "$line1")
          end_time_str=$(cut -f5 -d' ' <<< "$line1")

          start=${start_time_str#black_start:}
          end=${end_time_str#black_end:}

          Vstart_times+=("$start")
          Vend_times+=("$end")
        fi
    done <<< "$black_output"

    # Get the length of the blackdetect and silencedetect arrays for the loops
    VarrayLen=${#Vstart_times[@]}
    arrayLen=${#start_times[@]}

    # For every found blackdetect period, process it
    for (( vi=0; vi<${VarrayLen}; vi++ )); do
      # Calculate time between the start of the current blackdetect and the end of the file
      timetoend=$(awk "BEGIN {printf \"%.0f\", $videoduration - ${Vstart_times[$vi]}}")
      # Calculate time between the start of the current blackdetect and the start of the last blackdetect written as a chapter
      timesincelast=$(awk "BEGIN {printf \"%.0f\", ${Vstart_times[$vi]} - $lastChapter}")
      # Calculate blackdetect period length. This is faster than saving it from the backdetect output
      video_length=$(awk "BEGIN {printf ${Vend_times[$vi]} - ${Vstart_times[$vi]}}")

      # If the start time of the blackedetect period is later than 4 minutes, check within 4 minute ranges for best match, else check within 1 minute ranges. This is to help keep intros from being skipped over by the best match checks.
      if [[ -n $introEnd ]]; then
        durationCheck=$(awk -v vstart="${Vstart_times[$vi]}" -v endTime="$timetoend" -v introEnd="$introEnd" 'BEGIN {
          if (vstart >= introEnd) print "210"; else print "59" }')
      else
        durationCheck=$(awk -v vstart="${Vstart_times[$vi]}" -v endTime="$timetoend" 'BEGIN {
          if (vstart >= 240) print "210"; else print "59" }')
      fi

      # Check if the start time of the blackdetect period is lower than 10 seconds
      durationCheck2=$(awk -v vstart="${Vstart_times[$vi]}" 'BEGIN { if (vstart < 10) print "TRUE"; else print "FALSE" }')

      # If the duration of best match is 0 and the start time is greater than 10 seconds, set timesincelast equal to the minimum distance between scenes. This will allow shorter intros to be detected at the start of the video
      if [[ "$bestMatchDuration" = 0 ]] && [[ "$durationCheck2" = "FALSE" ]]; then
        timesincelast=$durationCheck
      fi

      timesincestart=$(awk "BEGIN {printf \"%.0f\", ${Vstart_times[$vi]}}")
      if [[ -n $startTime ]]; then
        startTimeVar=$(awk "BEGIN {printf \"%.0f\", ${startTime}}")
      else
        startTimeVar=0
      fi


      # Check if it's been at least x seconds from the last chapter AND if there's more than 15 seconds remaining in the video AND if the start time of the blackdetect period isn't in the first 10 seconds of the video
      if ([ "$timesincelast" -ge "$durationCheck" ] && [ "$timetoend" -ge 25 ] && [ "$timesincestart" -ge 25 ]) && ([ "$timesincestart" -ge "$startTimeVar" ] || [ "$startTimeVar" == 0 ]); then
        # For every found silencedetect period, process it in comparison to the current blackdetect period
        for (( i=$lastMatch; i<${arrayLen}; i++ )); do
          # Check if the silencedetect period and blackdetect period overlap at all
          simple_check=$(awk -v vstart="${Vstart_times[$vi]}" -v vend="${Vend_times[$vi]}" -v astart="${start_times[$i]}" -v aend="${end_times[$i]}" -v duration="$video_length" 'BEGIN { if (astart > vend || vstart > aend) print "FALSE"; else print "TRUE" }')
          check_2=$(awk -v vend="${Vend_times[$vi]}" -v astart="${start_times[$i]}" 'BEGIN { if (astart > vend) print "TRUE"; else print "FALSE" }')
          # If they do, proceed
          if [[ "$simple_check" = "TRUE" ]]; then
            sound_length=$(awk "BEGIN {printf ${end_times[$i]} - ${start_times[$i]}}")
            # Check if the blackdetect period or silencedetect period ends last
            check_end_last=$(awk -v vstart="${Vstart_times[$vi]}" -v vend="${Vend_times[$vi]}" -v astart="${start_times[$i]}" -v aend="${end_times[$i]}" -v duration="$video_length" 'BEGIN { if (aend >= vend) print "AUDIO"; else if (vend > aend) print "VIDEO"; }')
            # Check if the blackdetect period or silencedetect period starts last
            check_start_last=$(awk -v vstart="${Vstart_times[$vi]}" -v vend="${Vend_times[$vi]}" -v astart="${start_times[$i]}" -v aend="${end_times[$i]}" -v duration="$video_length" 'BEGIN { if (astart >= vstart) print "AUDIO"; else if (vstart > astart) print "VIDEO"; }')

            # Calculate how much the blackdetect period and silencedetect periods overlap and then convert it to a percentage of the duration of each
            if [[ $check_end_last = "AUDIO" ]] && [[ $check_start_last = "AUDIO" ]]; then
              percentMatchA=$(awk "BEGIN {printf \"%.0f\", ((${Vend_times[$vi]} - ${start_times[$i]}) / $sound_length) * 100}")
              percentMatchV=$(awk "BEGIN {printf \"%.0f\", ((${Vend_times[$vi]} - ${start_times[$i]}) / $video_length) * 100}")
            elif [[ $check_end_last = "VIDEO" ]] && [[ $check_start_last = "AUDIO" ]]; then
              percentMatchA=$(awk "BEGIN {printf \"%.0f\", ($sound_length / $sound_length) * 100}")
              percentMatchV=$(awk "BEGIN {printf \"%.0f\", ($sound_length / $video_length) * 100}")
            elif [[ $check_end_last = "VIDEO" ]] && [[ $check_start_last = "VIDEO" ]]; then
              percentMatchA=$(awk "BEGIN {printf \"%.0f\", ((${end_times[$i]} - ${Vstart_times[$vi]}) / $sound_length) * 100}")
              percentMatchV=$(awk "BEGIN {printf \"%.0f\", ((${end_times[$i]} - ${Vstart_times[$vi]}) / $video_length) * 100}")
            elif [[ $check_end_last = "AUDIO" ]] && [[ $check_start_last = "VIDEO" ]]; then
              percentMatchA=$(awk "BEGIN {printf \"%.0f\", ($video_length / $sound_length) * 100}")
              percentMatchV=$(awk "BEGIN {printf \"%.0f\", ($video_length / $video_length) * 100}")
            fi

            if [[ -n $minDur ]]; then
              minDurCheck=$(awk -v min="${minDur}" -v alen="$sound_length" -v vlen="$video_length" 'BEGIN { if (vlen > min || alen > min) print "TRUE"; else print "FALSE" }')
            fi
            if [[ -n $maxDur ]]; then
              maxDurCheck=$(awk -v min="${maxDur}" -v alen="$sound_length" -v vlen="$video_length" 'BEGIN { if (vlen < min || alen < min) print "TRUE"; else print "FALSE" }')
            fi

            # Validation checks to improve scene detection results. These are ignored if the breaks flag is set to short, necessary for shows that don't have long gaps between commercials
            if { { [[ "$percentMatchA" -lt 30 ]] && [[ "$percentMatchV" -lt 90 ]] ; } || { [[ "$percentMatchA" -lt 10 ]] || [[ "$percentMatchV" -lt 10 ]]; } || { [[ "$percentMatchA" -lt 40 ]] && [[ "$percentMatchV" -lt 40 ]]; } || { [[ "$percentMatchA" -lt 25 ]] && [[ "$percentMatchV" = 100 ]]; } || { [[ "$percentMatchV" -lt 25 ]] && [[ "$percentMatchA" = 100 ]]; } || { [[ "$minDurCheck" = "FALSE" ]] && [[ -n $minDur ]]; } || { [[ "$maxDurCheck" = "FALSE" ]] && [[ -n $maxDur ]]; }; } && [ "$breaks" != "short" ] && [ "$timetoend" -gt 45 ] ; then
              :
            else
              # If there is a current best match (see next comment)
              if [[ ! "$bestMatch" = "0" ]]; then
                # Check if it's been more than x seconds since the current best match was saved
                timeCheck=$(awk -v bestStart="$bestMatch" -v currentStart="${Vstart_times[$vi]}" -v durcheck="$durationCheck" 'BEGIN { if (bestStart <= (currentStart - durcheck)) print "TRUE"; else print "FALSE"}')
                # If it has been, then write it as a chapter
                if [[ "$timeCheck" == "TRUE" ]]; then
                  make_chapter
                fi
              fi
              # Check if the current blackperiod being analyzed is longer than the current best match within the past 59 seconds. This should help prevent the time between chapters casuing a false positive that is found first from writing a chapter and keeping an actual scene break from writing
              bestMatchCheck=$(awk -v duration1="$bestMatchDuration" -v duration2="$video_length" -v time1="$bestMatch" -v time2="${Vstart_times[*]}" -v arrayindex="$vi" -v audio1="$bestMatchAudio" -v audio2="$sound_length" -v durcheck="$durationCheck" -v vmatch1="$bestMatchPercentV" -v vmatch2="$percentMatchV" -v amatch1="$bestMatchPercentA" -v amatch2="$percentMatchA" 'BEGIN {
                n = split(time2, elements, ",")
                if ((duration2 + audio2) >= (duration1 + audio1) && (vmatch2 + amatch2) >= (vmatch1 + amatch1) && elements[arrayindex] <= (time1 + durcheck)){
                  print "TRUE";
                } else {
                  print "FALSE";
                }
              }')

              # If the current blackdetect period is the best match or there is no current best match, save the current blackdetect period as the best match
              if [[ "$bestMatchCheck" = "TRUE" ]] || [[ "$bestMatch" = "0" ]]; then
                bestMatch="${Vstart_times[$vi]}"
                bestMatchDuration="$video_length"

                # Calculate the duration of the matching silencedetect. The output of silence_duration from silencedetect was not reliable
                bestMatchAudio="$sound_length"
                bestMatchAudioStart="${start_times[$i]}"
                bestMatchPercentV="$percentMatchV"
                bestMatchPercentA="$percentMatchA"

                bestMatchText="\nSound\nMatch :  $percentMatchA%\nLength:  $sound_length\nStart :  ${start_times[$i]}\nEnd   :  ${end_times[$i]}\n\nVideo\nMatch :  $percentMatchV%\nLength:  $video_length\nStart :  ${Vstart_times[$vi]}\nEnd   :  ${Vend_times[$vi]}\n"
              fi
            fi
            # Set the last matched silencedetect period to the current one. This will keep the next blackdetect period from getting compared to anything prior to this match and speed up processing
            lastMatch=$i
          elif [[ "$check_2" = "TRUE" ]]; then
            # Breaks the i loop so the already matched blackdetect period doesn't need to check the entire silencedetect array
            break
          fi
        done
      fi
    done

    # Checks if the last chapter was written and writes it if not
    if [[ "$bestMatch" != "0" ]]; then
      make_chapter
    fi

    # If no chapters were found since the beginning of the file, add one at the end
    if [[ "$counter" = "1" ]]; then
      end_time=$(date -u -d@"$videoduration" +%H:%M:%S.%3N)
      echo -e "CHAPTER02=$end_time\nCHAPTER02NAME=Chapter 2\n"
    fi

    # Sets the total chapter count for command line output
    chapter_count="$counter"
    chaptersTotal+=("$chapter_count")
    filesArray+=("$1")
}

function make_chapter()
{
  # Checks if the length of the silencedetect period is more than 150% of the blackdetect period. This was added as several false positives during testing resulted from silencedetect periods that were significantly longer than the matched blackdetect period.
  #durationCompare=$(awk -v duration1="$bestMatchDuration" -v duration2="$bestMatchAudio" 'BEGIN { if (duration2 > duration1 * 1.5) print "TRUE"; else print "FALSE"}')

  # If the silencedetect period was longer than 150% of the blackdetect period, do nothing ELSE write the chapter
  #if [[ "$durationCompare" = "TRUE" ]]; then
  #  :
  #else
    # Sets the last chapter to the one being currently written
    lastChapter="$bestMatch"
    # Gets the time for the midpoint of the blackdetect period
    chapter_str=$(awk "BEGIN {printf \"%.3f\", (($bestMatchAudioStart + ($bestMatchAudio / 2)) + ($bestMatch + ($bestMatchDuration / 2))) / 2}")
    # Adds one to the chapter counter
    counter=$(($counter + 1))

    # Format the chapter number for output to the chapters text file
    chapter_num="0${counter}"
    chapter_num=${chapter_num:0:2}
    # Format the chapter timecode for output to the chapters text file
    chapter_time=$(date -u -d@"$chapter_str" +%H:%M:%S.%3N)
    # Write the chapter to the file and provide a notification in the command prompt
    echo -e "CHAPTER$chapter_num=$chapter_time\nCHAPTER${chapter_num}NAME=Chapter $counter\n"
    echo -e "Found Chapter $counter at ${GREEN}[$chapter_time]${NC}" >&2
    if [[ "$mode" = "debug" ]]; then
      echo -e "$bestMatchText" >&2
    fi
  #fi
  # Resets the current best match
  bestMatch=0
  bestMatchDuration=0
  bestMatchAudio=0
  bestMatchAudioStart=0
  bestMatchPercentV=0
  bestMatchPercentA=0
}

function print_usage
{
    echo "Usage: $(basename "$0") <File / Directory>"
}

logfile="$(basename "$(realpath "$1")")_blackdetect.txt"

# Assure a valid amount of command-line arguments were passed
if [[ $# -lt 1 ]]; then
    echo "Error: Missing a parameter." >&2
    print_usage
    exit 1
fi

# Assure file / directory exists
if [[ ! -e "$1" ]]; then
    echo "Error: Directory / file \"$1\" not found." >&2
    print_usage
    exit 1
fi

# Checks if the user-input is a directory
if [[ -d "$1" ]]; then
  # For every mkv file in the directory, process it
  for file_path in "$1"/*.mkv; do
      # Set the path for the chapter file
      chapfile="${file_path#.mkv}_blackdetect.txt"
      # Clear the file if it already exists
      truncate -s 0 "$chapfile"
      # Process the mkv file
      blackdetect "$file_path" >> "$chapfile"
      echo -e "\n\n" >> "$chapfile"
      # Remove existing chapters from the mkv file
      mkvpropedit -q -c '' "$file_path"
      # Adds the found chapters to the mkv file
      mkvpropedit -q -c "$chapfile" "$file_path"
      # Notifies the user how many chapters were added and how long it took to process the mkv file
      echo -e "\nFound and wrote ${GREEN}$counter${NC} chapters to ${CYAN}$file_path${NC} in ${LGREEN}$(($SECONDS / 60 % 60))${NC}min ${LGREEN}$(($SECONDS % 60))${NC}sec\n\n"
      # Deletes the chapter file
      rm "$chapfile"
  done
  averageChapters=($(printf "%s\n" "${chaptersTotal[@]}" | sort -n -r | uniq -c | sort -n -r | head -1 | awk '{print $2}'))

  fileArrayLen=${#filesArray[@]}

  for (( ci=0; ci<${fileArrayLen}; ci++ )); do
    if [[ "${chaptersTotal[$ci]}" -ne "${averageChapters[0]}" ]]; then
      diff=$(("${chaptersTotal[$ci]}"-"${averageChapters[0]}"))
      if [[ "$diff" -lt 0 ]]; then
        diff=$(("$diff" * "-1"))
        echo -e "\n${RED}**CHAPTER DISCREPANCY**${NC} ${CYAN}${filesArray[$ci]}${NC} has $diff chapters fewer than the average file in this batch \n" >&2
      else
        echo -e "\n${RED}**CHAPTER DISCREPANCY**${NC} ${CYAN}${filesArray[$ci]}${NC} has $diff chapters more than the average file in this batch \n" >&2
      fi
    fi
  done
elif [[ -f "$1" ]]; then
    blackdetect "$1" > "$logfile"
    mkvpropedit -c '' "$1"
    mkvpropedit -c "$logfile" "$1"
    printf "%b\nDONE $1\n\n"
    rm "$logfile"
fi
