#!/bin/bash

# ==========================================
# CONFIGURATION SETUP
# ==========================================
# Change this path to the absolute directory where your games live
GAMES_ROOT_DIR="./Games"

curl -L -O https://github.com/Minecatl1/Gami-launcher/raw/refs/heads/main/games_list.txt

LIST_FILE="games_list.txt"
INSTALLED_FILE="installed_games.txt"

# Ensure foundational tracking files exist safely
touch "$LIST_FILE" "$INSTALLED_FILE"

while true; do
    # Main Dashboard Menu Interface
    CHOICE=$(zenity --list --title="Game Manager Dashboard" \
        --column="Action" --column="Description" \
        --width=420 --height=320 \
        "Install" "Download and extract new games from list" \
        "Manage Installed" "Run, Stop, or Remove installed games" \
        "Exit" "Close the application")

    # Terminate script gracefully if user cancels or selects Exit
    if [ $? -ne 0 ] || [ "$CHOICE" == "Exit" ]; then
        break
    fi

    # ==========================================
    # FLOW: INSTALLATION MANAGEMENT
    # ==========================================
    if [ "$CHOICE" == "Install" ]; then
        ZENITY_ARGS=()
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            GAME_NAME=$(echo "$line" | cut -d'/' -f2)
            ZENITY_ARGS+=("$GAME_NAME" "$line")
        done < "$LIST_FILE"

        # Final layout array anchor row for manual repo entry prompts
        ZENITY_ARGS+=("[ + Add Custom Repo ]" "MANUAL_ENTRY")

        SELECTED_GAME=$(zenity --list --title="Available Games" \
            --text="Select a game to install or add a new one to your text catalog:" \
            --column="Game Name" --column="Repository Source" \
            --width=550 --height=420 "${ZENITY_ARGS[@]}")

        [ $? -ne 0 ] && continue

        # Handle Custom Repository Entry Additions
        if [ "$SELECTED_GAME" == "[ + Add Custom Repo ]" ]; then
            NEW_REPO=$(zenity --entry --title="Add Custom Game" \
                --text="Enter the target repository in standard 'maker/game' format:")
            
            if [ -n "$NEW_REPO" ] && [[ "$NEW_REPO" == */* ]]; then
                echo "$NEW_REPO" >> "$LIST_FILE"
                zenity --info --text="Successfully added $NEW_REPO to tracking list!" --timeout=2
            else
                zenity --error --text="Invalid naming structure. Please adhere to 'maker/game' layout format."
            fi
            continue
        fi

        # Extract precise matching target repository entry string
        REPO_PATH=$(grep "/$SELECTED_GAME$" "$LIST_FILE" | head -n 1)
        
        URL="https://github.com/${REPO_PATH}/releases/download/V3.0.0/${SELECTED_GAME}.tar.xz"
        OUTPUT_FILE="${SELECTED_GAME}.tar.xz"
        TARGET_FOLDER="${GAMES_ROOT_DIR}/${SELECTED_GAME}"
		echo $URL
        # Fetch archive asset with active processing pipeline for Zenity progress metric tracking
        curl -L -O "$URL" 2>&1 | \
        stdbuf -o0 tr '\r' '\n' | \
        stdbuf -o0 awk '
            /^[ ]*[0-9]/ { print $1; fflush() }
            /^-------/ { print "# Downloading package archive files..."; fflush() }
        ' | zenity --progress --title="Installing $SELECTED_GAME" \
                   --text="Connecting to remote GitHub servers..." --percentage=0 --auto-close

        if [ ${PIPESTATUS} -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
            # Build parent workspace target subfolder if it does not yet exist
            mkdir -p "$TARGET_FOLDER"
	
            # Decompress and unpack contents cleanly into its isolated named directory structure
            tar -xvf "$OUTPUT_FILE" -C "$TARGET_FOLDER" 2>&1 | \
            zenity --progress --title="Extracting System Assets" \
                   --text="Unpacking dependencies into: ${TARGET_FOLDER}" --pulsate --auto-close

            # Clean up transient tarball archive and append success token markers locally
            rm -f "$OUTPUT_FILE"
            echo "$SELECTED_GAME" >> "$INSTALLED_FILE"
            
            zenity --info --text="$SELECTED_GAME folder initialized. Verification complete!" --timeout=3
        else
            zenity --error --text="Download transaction failed. Verify repository connectivity or build tags."
            rm -f "$OUTPUT_FILE"
        fi

    # ==========================================
    # FLOW: LIBRARY OPERATIONS MANAGEMENT
    # ==========================================
    elif [ "$CHOICE" == "Manage Installed" ]; then
        # Read unique locally logged target index items into memory array
        INSTALLED_GAMES=($(cat "$INSTALLED_FILE" 2>/dev/null))
        
        if [ ${#INSTALLED_GAMES[@]} -eq 0 ]; then
            zenity --info --text="Your installed execution library is currently empty."
            continue
        fi

        MNG_GAME=$(zenity --list --title="Installed Game Library" \
            --column="Game Directory Engine" "${INSTALLED_GAMES[@]}")
            
        [ $? -ne 0 ] && continue

        # Actions Selection Panel Matrix 
        OP=$(zenity --list --title="Control Actions: $MNG_GAME" \
            --column="Operational Command" "Run" "Stop" "Remove")
            
        [ $? -ne 0 ] && continue

        case "$OP" in
            "Run")
                # Direct pointer link to your unique pre-existing game launch target file paths
                LAUNCHER="${GAMES_ROOT_DIR}/${MNG_GAME}/run_${MNG_GAME}.sh"
                
                if [ -f "$LAUNCHER" ]; then
                    zenity --info --text="Executing launcher script for $MNG_GAME..." --timeout=2
                    # Run launcher explicitly as an isolated background task
                    bash "$LAUNCHER" &
                else
                    zenity --error --text="Execution Failure: Could not locate expected path script at:\n$LAUNCHER"
                fi
                ;;
                
            "Stop")
                # Identifies the unique running background bash instance executing your pre-made run script
                TARGET_SCRIPT="run_${MNG_GAME}.sh"
                
                # Retrieve process IDs (PIDs) running that specific filename string match
                PIDS=$(pgrep -f "$TARGET_SCRIPT")
                
                if [ -n "$PIDS" ]; then
                    zenity --info --text="Terminating operational runtime for $MNG_GAME..." --timeout=2
                    # Terminate process handles gracefully
                    kill $PIDS
                else
                    zenity --info --text="$MNG_GAME does not appear to have an active runtime session running." --timeout=2
                fi
                ;;
                
            "Remove")
                # Confirmation security dialog to prevent unintended loss of game directories
                zenity --question --title="Confirm File Purge" \
                    --text="Are you absolutely sure you want to completely remove ${MNG_GAME} and delete its folder directory?"
                
                if [ $? -eq 0 ]; then
                    # Clean out target local directory contents permanently 
                    rm -rf "${GAMES_ROOT_DIR}/${MNG_GAME}"
                    
                    # Wipe track logs safely inside metadata files
                    sed -i "/^$MNG_GAME$/d" "$INSTALLED_FILE"
                    zenity --info --text="Purge complete. ${MNG_GAME} removed successfully." --timeout=2
                fi
                ;;
        esac
    fi
done
