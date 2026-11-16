//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import MediaAccessibilityKit
import SwiftUI

extension VideoPlayer.PlaybackControls.Toolbar.ActionButtons {

    struct Subtitles: View {

        @Environment(MediaSession.self)
        private var mediaSession
        @Environment(\.scenePhase)
        private var scenePhase

        @State
        private var profiles = CaptionProfile.availableForCurrentPlatform

        private var systemImage: String {
            if mediaSession.playbackItem?.subtitlesEnabled == true {
                VideoPlayerActionButton.subtitles.systemImage
            } else {
                VideoPlayerActionButton.subtitles.secondarySystemImage
            }
        }

        var body: some View {
            if let playbackItem = mediaSession.playbackItem {
                Menu {
                    SubtitleOptions(playbackItem: playbackItem, profiles: profiles)
                } label: {
                    Label(L10n.subtitles, systemImage: systemImage)

                    if playbackItem.isShowingSubtitlesOnSkipBack {
                        Text(L10n.showOnSkipBack)
                    }
                }
                .menuOrder(.fixed)
                .disabled(!mediaSession.canControlPlayback)
                .task(id: scenePhase) {
                    if #available(iOS 26, tvOS 26, *) {
                        for await profiles in CaptionProfile.updates {
                            self.profiles = profiles
                        }
                    }
                }
            }
        }
    }

    private struct SubtitleOptions: View {

        @Default(.VideoPlayer.Subtitle.captionProfileID)
        private var selectedProfileID

        @Environment(MediaSession.self)
        private var mediaSession

        let playbackItem: MediaPlayerItem
        let profiles: [CaptionProfile]

        private func streams(secondary: Bool) -> [MediaStream] {
            (secondary ? playbackItem.secondarySubtitleStreams : playbackItem.subtitleStreams)
                .filter { ($0.index ?? -1) >= 0 }
                .filter { !secondary || $0.index != playbackItem.subtitleTrackIndex(secondary: false) }
        }

        private var isEnabled: Binding<Bool> {
            Binding(
                get: { playbackItem.subtitlesEnabled },
                set: { playbackItem.setSubtitlesEnabled($0) }
            )
        }

        private func trackIndex(secondary: Bool) -> Binding<Int> {
            Binding(
                get: { playbackItem.subtitleTrackIndex(secondary: secondary) },
                set: { playbackItem.setSubtitleTrack(index: $0, secondary: secondary) }
            )
        }

        private var profileID: Binding<String> {
            Binding(
                get: {
                    let id = selectedProfileID

                    return profiles.contains(where: { $0.id == id }) ? id : ""
                },
                set: { selectedProfileID = $0 }
            )
        }

        private func trackPicker(_ title: String, secondary: Bool) -> some View {
            Picker(selection: trackIndex(secondary: secondary)) {
                Text(L10n.none)
                    .tag(-1)

                ForEach(streams(secondary: secondary), id: \.index) { stream in
                    Text(stream.displayTitle ?? L10n.unknown)
                        .tag(stream.index ?? -1)
                }
            } label: {
                Text(title)

                if let stream = streams(secondary: secondary)
                    .first(property: \.index, equalTo: playbackItem.subtitleTrackIndex(secondary: secondary))
                {
                    Text(stream.displayTitle ?? L10n.unknown)
                } else {
                    Text(L10n.none)
                }
            }
            .pickerStyle(.menu)
            .disabled(streams(secondary: secondary).isEmpty)
        }

        #if os(tvOS)
        // Direct actions avoid the nested Menu/Picker focus trap on Siri Remote.
        private func trackOptions(_ title: String, secondary: Bool) -> some View {
            Section(title) {
                Button {
                    if secondary {
                        playbackItem.setSubtitleTrack(index: -1, secondary: true)
                    } else {
                        playbackItem.setSubtitlesEnabled(false)
                    }
                } label: {
                    if secondary ? playbackItem.subtitleTrackIndex(secondary: true) == -1 : !playbackItem.subtitlesEnabled {
                        Label(L10n.none, systemImage: "checkmark")
                    } else {
                        Text(L10n.none)
                    }
                }

                ForEach(streams(secondary: secondary), id: \.index) { stream in
                    Button {
                        playbackItem.setSubtitleTrack(index: stream.index ?? -1, secondary: secondary)
                        if !secondary {
                            playbackItem.setSubtitlesEnabled(true)
                        }
                    } label: {
                        if playbackItem.subtitleTrackIndex(secondary: secondary) == stream.index
                            && (secondary || playbackItem.subtitlesEnabled)
                        {
                            Label(stream.displayTitle ?? L10n.unknown, systemImage: "checkmark")
                        } else {
                            Text(stream.displayTitle ?? L10n.unknown)
                        }
                    }
                }
            }
        }
        #endif

        var body: some View {
            #if os(tvOS)
            Section(L10n.subtitles) {
                Button {
                    playbackItem.setSubtitlesEnabled(true)
                } label: {
                    if playbackItem.subtitlesEnabled {
                        Label(L10n.on, systemImage: "checkmark")
                    } else {
                        Text(L10n.on)
                    }
                }
                .disabled(streams(secondary: false).isEmpty)

                Button {
                    playbackItem.setSubtitlesEnabled(false)
                } label: {
                    if !playbackItem.subtitlesEnabled {
                        Label(L10n.off, systemImage: "checkmark")
                    } else {
                        Text(L10n.off)
                    }
                }
            }

            trackOptions(
                playbackItem.supportsSecondarySubtitles ? L10n.primarySubtitles : L10n.subtitleTrack,
                secondary: false
            )

            if playbackItem.supportsSecondarySubtitles {
                trackOptions(L10n.secondarySubtitles, secondary: true)
            }

            Section(L10n.textStyle) {
                Button {
                    selectedProfileID = ""
                } label: {
                    if profileID.wrappedValue.isEmpty {
                        Label(L10n.system, systemImage: "checkmark")
                    } else {
                        Text(L10n.system)
                    }
                }

                ForEach(profiles) { profile in
                    Button {
                        selectedProfileID = profile.id
                    } label: {
                        if profileID.wrappedValue == profile.id {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                }

                SystemSettingsButton(title: L10n.captionStyleSettings, destination: .captionStyles)
            }
            #else
            Section {
                Picker(L10n.subtitles, selection: isEnabled) {
                    Button {
                        playbackItem.setSubtitlesEnabled(true)
                    } label: {
                        Text(L10n.on)

                        if playbackItem.isShowingSubtitlesOnSkipBack {
                            Text(L10n.showOnSkipBack)
                        }
                    }
                    .tag(true)
                    .disabled(streams(secondary: false).isEmpty)

                    Text(L10n.off).tag(false)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                trackPicker(playbackItem.supportsSecondarySubtitles ? L10n.primarySubtitles : L10n.subtitleTrack, secondary: false)

                if playbackItem.supportsSecondarySubtitles {
                    trackPicker(L10n.secondarySubtitles, secondary: true)
                }

                Menu {
                    Picker(L10n.textStyle, selection: profileID) {
                        Text(L10n.system).tag("")

                        ForEach(profiles) { profile in
                            Text(profile.name)
                                .tag(profile.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
//                    .disabled(profiles.isEmpty || mediaSession.player?.mediaPlayerType != .mpv)

                    Section {
                        SystemSettingsButton(title: L10n.captionStyleSettings, destination: .captionStyles)
                    }
                } label: {
                    Text(L10n.textStyle)

                    Text(profiles.first(property: \.id, equalTo: profileID.wrappedValue)?.name ?? L10n.system)
                }
                .menuOrder(.fixed)
            }
            #endif
        }
    }
}
