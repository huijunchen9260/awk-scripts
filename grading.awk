#!/usr/bin/awk -f

# Steps:
# Go to https://osu.instructure.com/api/v1/courses/{course_id}/discussion_topics/{discussion_id}/view?include_new_entries=1&include_enrollment_state=1
# Download pretty printed json file
# Run jq '.view' file.json | ./grading.awk --csv csvfile
# Run jq '.view' file.json | ./grading.awk --csv csvfile | xclip -selection clipboard
#	to copy to clipboard
# Argument explained:
# --csv: Carmen csv file to align students id
# --gradeonly: only generate grade
# paste back to downloaded gradebook and import back to carmen.

BEGIN {
    pos = 0
    while (ARGV[++pos]) {
        if (ARGV[pos] == "--csv") {
	    delete ARGV[pos]
            file = ARGV[++pos]
	    delete ARGV[pos]
        }
        if (ARGV[pos] == "--gradeonly") {
	    delete ARGV[pos]
            gradeind = 1
        }
        if (ARGV[pos] == "--wordcount") {
	    delete ARGV[pos]
	    wcind = 1
	}

    }

    total_point = 3

    # word count standard
    main_upper = 150
    main_middle = 50
    main_lower = 0
    reply_upper = 20
    reply_middle = 10
    reply_lower = 0

    # word count points
    main_upper_pt = 1
    main_middle_pt = 0.5
    main_lower_pt = 0.1
    reply_upper_pt = 1
    reply_middle_pt = 0.3
    reply_lower_pt = 0.1
}

{
    RS = "\f"
    FS = "\n"

    split($0, jsonarr, "\n")
    replyind = 0
    for (item in jsonarr) {
	if (jsonarr[item] ~ /.*"parent_id": null.*/) {
	    replyind = 0
	}
	else if (jsonarr[item] ~ /.*"parent_id": [0-9]*.*/) {
	    replyind = 1
	}

	if (jsonarr[item] ~ /^.*"user_id".*/) {
	    gsub(/^.*"user_id": |,$/, "", jsonarr[item])
	    id = jsonarr[item]
	}
	if (jsonarr[item] ~ /^.*message.*/ && replyind == 0) {
	    gsub(/^.*"message": |<\/?[[:alnum:]]*>|\\n|&nbsp;|,$|"/, "", jsonarr[item])
	    msgarr[id] = msgarr[id] ",'" jsonarr[item] "'"
	    wordcount = split(jsonarr[item], countarr, "[[:blank:]]")
	    wcmsgarr[id] = wcmsgarr[id] "," wordcount
	}
	if (jsonarr[item] ~ /^.*message.*/ && replyind == 1) {
	    gsub(/^.*"message": |<\/?[[:alnum:]]*>|\\n|&nbsp;|,$|"/, "", jsonarr[item])
	    replyarr[id] = replyarr[id] ",'" jsonarr[item] "'"
	    wordcount = split(jsonarr[item], countarr, "[[:blank:]]")
	    wcreplyarr[id] = wcreplyarr[id] "," wordcount
	}
    }

    for (id in wcmsgarr) {
        replynum = split(wcmsgarr[id], countarr, ",")
	for (count in countarr) {
	    if (countarr[count] >= main_upper){
		creditarr[id] += main_upper_pt
		continue
	    }
	    if (countarr[count] >= main_middle && countarr[count] < main_upper){
		creditarr[id] += main_middle_pt
		continue
	    }
	    if (countarr[count] > main_lower) {
		creditarr[id] += main_lower_pt
		continue
	    }
	}
    }

    for (id in wcreplyarr) {
        replynum = split(wcreplyarr[id], countarr, ",")
	for (count in countarr) {
	    if (countarr[count] >= reply_upper){
		creditarr[id] += reply_upper_pt
		continue
	    }
	    if (countarr[count] >= reply_middle && countarr[count] < reply_upper){
		creditarr[id] += reply_middle_pt
		continue
	    }
	    if (countarr[count] > reply_lower) {
		creditarr[id] += reply_lower_pt
		continue
	    }
	}
	if (creditarr[id] > total_point) {
	    creditarr[id] = total_point
	}
    }

}

END {
    getline csv < file

    narr = split(csv, csvarr, "\n")
    delete csvarr[1]
    delete csvarr[2]
    delete csvarr[narr]
    for (student in csvarr) {
	ind = 0
	split(csvarr[student], fieldarr, ",")
	for (id in creditarr) {
	    if (id == fieldarr[3]) {
		ind = 1;
		if (wcind == 1) {
		    print id "," creditarr[id] wcmsgarr[id] wcreplyarr[id]
		    break
		}
		if (gradeind == 1) {
		    print creditarr[id]
		    break
		}
		print id "," creditarr[id] msgarr[id] replyarr[id]
		break
	    }
	}
	if (ind == 0) {
	    id = fieldarr[3]
	    if (gradeind == 1 || wcind == 1) {
		print 0
	    }
	    else {
		print id "," 0
	    }
	}

    }
}



function notify(msg, str) {
    system("stty -cread icanon echo 1>/dev/null 2>&1")
    print msg
    RS = "\n" # stop getline by enter
    getline str < "-"
    RS = "\f"
    return str
    system("stty sane")
}
