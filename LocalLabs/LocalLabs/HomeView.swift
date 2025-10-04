//
//  HomeView.swift
//  LocalLabs
//
//  Main landing screen with greeting, search, and conversation history
//

import SwiftUI
import SwiftData

/// Main home screen of the app
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var searchText = ""
    @State private var selectedConversation: Conversation?
    @State private var showingChat = false
    @State private var showingNewChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        // Greeting Section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hi, Human 👋")
                                .font(AppTheme.Typography.largeTitle())
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            Text("How may I help you today?")
                                .font(AppTheme.Typography.title())
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.sm)

                        // Search Bar
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .font(.system(size: 14))

                            TextField("Search...", text: $searchText)
                                .font(AppTheme.Typography.subheadline())
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .tint(AppTheme.Colors.accent)
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.cardBackground)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .padding(.horizontal, AppTheme.Spacing.lg)

                        // Action Cards
                        HStack(spacing: AppTheme.Spacing.lg) {
                            ActionCard(
                                title: "Engage in conversation with AI.",
                                isAccent: true
                            ) {
                                startNewConversation()
                            }

                            ActionCard(
                                title: "Converse with Artificial Intelligence.",
                                isAccent: false
                            ) {
                                startNewConversation()
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)

                        // Conversation History Section
                        if !filteredConversations.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                Text("Conversation History")
                                    .font(AppTheme.Typography.body())
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .padding(.horizontal, AppTheme.Spacing.lg)

                                VStack(spacing: AppTheme.Spacing.sm) {
                                    ForEach(filteredConversations) { conversation in
                                        ConversationHistoryRow(
                                            conversation: conversation,
                                            onTap: {
                                                openConversation(conversation)
                                            },
                                            onDelete: {
                                                deleteConversation(conversation)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, AppTheme.Spacing.lg)
                            }
                        } else if !searchText.isEmpty {
                            // No search results
                            VStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.Colors.textTertiary)

                                Text("No conversations found")
                                    .font(AppTheme.Typography.body())
                                    .foregroundColor(AppTheme.Colors.textSecondary)

                                Text("Try adjusting your search")
                                    .font(AppTheme.Typography.caption())
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.xl)
                        } else {
                            // Empty state - no conversations yet
                            VStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.Colors.textTertiary)

                                Text("No conversations yet")
                                    .font(AppTheme.Typography.body())
                                    .foregroundColor(AppTheme.Colors.textSecondary)

                                Text("Start a new conversation to get started")
                                    .font(AppTheme.Typography.caption())
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.xl)
                        }

                        Spacer(minLength: AppTheme.Spacing.xl)
                    }
                }
            }
            .navigationDestination(isPresented: $showingChat) {
                if let conversation = selectedConversation {
                    ChatView(conversation: conversation)
                        .navigationBarHidden(true)
                }
            }
            .navigationDestination(isPresented: $showingNewChat) {
                ChatView(conversation: nil)
                    .navigationBarHidden(true)
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Computed Properties

    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                (conversation.lastMessage?.content.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    // MARK: - Actions

    private func startNewConversation() {
        selectedConversation = nil
        showingNewChat = true
    }

    private func openConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        showingChat = true
    }

    private func deleteConversation(_ conversation: Conversation) {
        withAnimation {
            modelContext.delete(conversation)
            try? modelContext.save()
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}
