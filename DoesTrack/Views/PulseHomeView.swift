import SwiftUI

struct PulseView: View {
    @EnvironmentObject private var store: DoseStore
    @State private var prompt = ""
    @State private var showsPKModel = false
    @State private var showsFortnightlyReview = false
    @State private var showsChatInfo = false
    @State private var activeSheet: PulseSheet?
    @FocusState private var promptFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pulse")
                                .font(.largeTitle.bold())
                            Text("Protocol insights and local chat.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Button {
                            store.clearChat()
                        } label: {
                            Image(systemName: "plus.bubble")
                                .font(.title3.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(.white, in: Circle())
                        }
                        .foregroundStyle(.primary)
                        .disabled(store.chatMessages.isEmpty)
                        .accessibilityLabel("New chat")

                        Button {
                            showsChatInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.title3.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(.white, in: Circle())
                        }
                        .foregroundStyle(.primary)
                        .accessibilityLabel("About Pulse chat")
                    }

                    if let tenure = store.activeProtocolTenure() {
                        PulseHighlight(title: "\(tenure.weeks) Week\(tenure.weeks == 1 ? "" : "s") on Protocol", subtitle: tenure.stackName, systemImage: "calendar.badge.clock")
                    }

                    Button {
                        showsFortnightlyReview = true
                    } label: {
                        PulseHighlight(title: "Fortnightly Insights", subtitle: "Your 14-day health story across adherence, vitals, body composition, labs, and recommendations. Open your latest review.", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open your latest review")

                    Text("Insights")
                        .font(.headline)
                    HStack {
                        Button {
                            activeSheet = .insight(.symptoms)
                        } label: {
                            MiniInsight(title: "Symptoms", subtitle: "Analyze notes", systemImage: "heart.text.square", tint: .orange)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Symptoms")

                        Button {
                            activeSheet = .insight(.doseHistory)
                        } label: {
                            MiniInsight(title: "Dose History", subtitle: "Review logs", systemImage: "pills", tint: .blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dose History")

                        Button {
                            activeSheet = .insight(.riskFactors)
                        } label: {
                            MiniInsight(title: "Risk Factors", subtitle: "Review flags", systemImage: "exclamationmark.shield", tint: .red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Risk Factors")
                    }

                    Button {
                        showsPKModel = true
                    } label: {
                        PulseHighlight(title: "PK Model", subtitle: "Relative exposure curves with cited PK defaults.", systemImage: "function")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("PK Model")

                    Text("Discover Protocols")
                        .font(.headline)
                    StackSuggestionRow(title: "Optimize Your Stack", subtitle: "Find the right blend or stack for your goals", tag: "") {
                        activeSheet = .stacks
                    }
                    .accessibilityLabel("Optimize Your Stack")

                    Text("Understanding Your Protocol")
                        .font(.headline)
                    VStack(spacing: 10) {
                        Button {
                            activeSheet = .question(.doseMechanics)
                        } label: {
                            QuestionRow("How does my dose work?", "Learn about dosing and clearance")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("How does my dose work?")

                        Button {
                            activeSheet = .question(.timingAbsorption)
                        } label: {
                            QuestionRow("Timing & absorption", "Review injection timing")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Timing & absorption")

                        Button {
                            activeSheet = .question(.sideEffects)
                        } label: {
                            QuestionRow("Side effect management", "Review dose notes")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Side effect management")
                    }

                    if !store.chatMessages.isEmpty {
                        Text("Chat")
                            .font(.headline)
                        ChatThreadView(messages: store.chatMessages)
                    }

                    HStack {
                        TextField("Ask DoesTrack...", text: $prompt)
                            .textFieldStyle(.roundedBorder)
                            .focused($promptFocused)
                            .onSubmit(sendPrompt)
                        Button {
                            sendPrompt()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                        .accessibilityLabel("Ask DoesTrack")
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 6)

                    Label("Chat stored on device only. Not medical advice.", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .padding(.bottom, 110)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .alert("Pulse Chat", isPresented: $showsChatInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Replies are generated on this device from your tracked data. The thread is stored locally, excluded from GitHub backups, and is not medical advice.")
            }
            .sheet(isPresented: $showsPKModel) {
                PKModelView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsFortnightlyReview) {
                FortnightlyReviewView()
                    .environmentObject(store)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .insight(let kind):
                    PulseInsightDetailView(kind: kind)
                        .environmentObject(store)
                case .question(let topic):
                    ProtocolQuestionDetailView(topic: topic)
                        .environmentObject(store)
                case .stacks:
                    ProtocolStacksView()
                        .environmentObject(store)
                }
            }
        }
    }

    private func sendPrompt() {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        store.appendChatMessage(ChatMessage(role: .user, text: trimmedPrompt))

        let reply = PulseAssistantReply.make(prompt: trimmedPrompt, store: store)
        store.appendChatMessage(
            ChatMessage(role: .assistant, title: reply.title, text: reply.body, bullets: reply.bullets)
        )

        prompt = ""
        promptFocused = false
    }
}

struct PulseHighlight: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        ModelCard {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.appBlue)
                    .frame(width: 52, height: 52)
                    .background(Color.appBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MiniInsight: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.bold())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.10))
        }
    }
}

struct QuestionRow: View {
    var title: String
    var subtitle: String

    init(_ title: String, _ subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }
}
