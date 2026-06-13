//
//  QuestionnaireItem.swift
//  Matchly
//
//  Created on 11/14/25.
//

import Foundation

struct QuestionnaireItem: Codable, Identifiable, Equatable {
    let id: String
    let question: String
    var programRating: Double = 0 // 0 = unrated, 1-5 = rating, 6 = N/A
    var notes: String = ""
    
    init(id: String = UUID().uuidString, question: String, programRating: Double = 0, notes: String = "") {
        self.id = id
        self.question = question
        self.programRating = programRating
        self.notes = notes
    }
}

struct QuestionnaireSection: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var items: [QuestionnaireItem]
    
    init(id: String = UUID().uuidString, title: String, items: [QuestionnaireItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

struct Questionnaire: Codable, Equatable {
    var sections: [QuestionnaireSection]
    var customSections: [QuestionnaireSection] = [] // User-created custom sections (stored as QuestionnaireSection for consistency)
    
    // Helper to get section by index
    func section(at index: Int) -> QuestionnaireSection? {
        guard index >= 0 && index < sections.count else { return nil }
        return sections[index]
    }
    
    // Helper to get item by section and item index
    func item(sectionIndex: Int, itemIndex: Int) -> QuestionnaireItem? {
        guard let section = section(at: sectionIndex),
              itemIndex >= 0 && itemIndex < section.items.count else { return nil }
        return section.items[itemIndex]
    }
    
    init() {
        // Section A — Big-picture priorities
        let sectionA = QuestionnaireSection(
            title: "Section A — Big-picture priorities",
            items: [
                QuestionnaireItem(question: "Overall \"fit\" / gut feeling from interview day"),
                QuestionnaireItem(question: "Desired geographic location / ability to live where I want"),
                QuestionnaireItem(question: "Career goals alignment (academic vs community, research vs clinical)"),
                QuestionnaireItem(question: "Reputation / program prestige"),
                QuestionnaireItem(question: "Fellowship opportunities and fellowship match record"),
                QuestionnaireItem(question: "Job placement / alumni network after residency")
            ]
        )
        
        // Section B — Training quality & clinical experience
        let sectionB = QuestionnaireSection(
            title: "Section B — Training quality & clinical experience",
            items: [
                QuestionnaireItem(question: "Breadth and depth of clinical exposure (variety of cases)"),
                QuestionnaireItem(question: "Procedural volume / hands-on opportunities"),
                QuestionnaireItem(question: "Quality of teaching (faculty commitment to education, protected teaching time)"),
                QuestionnaireItem(question: "Board pass rates and objective outcomes"),
                QuestionnaireItem(question: "Strength of simulation, procedural labs, and learning resources"),
                QuestionnaireItem(question: "Research opportunities & support (funding, mentors, time)")
            ]
        )
        
        // Section C — Workload, schedule & lifestyle
        let sectionC = QuestionnaireSection(
            title: "Section C — Workload, schedule & lifestyle",
            items: [
                QuestionnaireItem(question: "Call schedule (frequency, night float vs home call)"),
                QuestionnaireItem(question: "Typical work hours / resident workload"),
                QuestionnaireItem(question: "Vacation / parental leave policies and flexibility"),
                QuestionnaireItem(question: "Opportunities for moonlighting or outside work"),
                QuestionnaireItem(question: "Salary, benefits, housing stipend if any"),
                QuestionnaireItem(question: "Cost of living in city / housing availability")
            ]
        )
        
        // Section D — Culture, support & wellbeing
        let sectionD = QuestionnaireSection(
            title: "Section D — Culture, support & wellbeing",
            items: [
                QuestionnaireItem(question: "Resident camaraderie / morale"),
                QuestionnaireItem(question: "Program leadership accessibility & responsiveness (PD/APDs)"),
                QuestionnaireItem(question: "Psychological safety (ability to speak up, reporting mistreatment)"),
                QuestionnaireItem(question: "Diversity, equity & inclusion climate"),
                QuestionnaireItem(question: "Mentorship availability (senior resident and faculty mentors)"),
                QuestionnaireItem(question: "Wellness resources (counseling, time off, wellness stipend)")
            ]
        )
        
        // Section E — Practical & logistic items
        let sectionE = QuestionnaireSection(
            title: "Section E — Practical & logistic items",
            items: [
                QuestionnaireItem(question: "Clinic structure / outpatient continuity experience"),
                QuestionnaireItem(question: "Elective flexibility (ability to tailor training)"),
                QuestionnaireItem(question: "Availability of subspecialty rotations or niche experiences I care about"),
                QuestionnaireItem(question: "Call coverage/backup, how nights are covered"),
                QuestionnaireItem(question: "Housing/commute time from hospital"),
                QuestionnaireItem(question: "Spousal/partner support (job market, community)")
            ]
        )
        
        // Section F — Red flags & dealbreakers (yes/no + comment)
        let sectionF = QuestionnaireSection(
            title: "Section F — Red flags & dealbreakers",
            items: [
                QuestionnaireItem(question: "Did you observe or hear any concerning behavior from faculty or residents?"),
                QuestionnaireItem(question: "Are there concerning board pass rates, litigation issues, or program probation history?"),
                QuestionnaireItem(question: "Do you feel you could see yourself living in this city for the length of training?"),
                QuestionnaireItem(question: "Any scheduling or leave policies that would be a dealbreaker?")
            ]
        )
        
        self.sections = [sectionA, sectionB, sectionC, sectionD, sectionE, sectionF]
    }
    
    // Calculate total weighted score (0-100) - weighted average of all enabled sections
    func totalWeightedScore(preferences: UserPreferences) -> Double {
        var sectionScores: [(sectionId: String, averageScore: Double, weight: Double)] = []
        
        // Get all enabled sections (standard + custom, excluding red flags)
        let allSections = sections + customSections
        let enabledSections = allSections.filter { section in
            // Check if section is enabled (empty set = all enabled)
            if !preferences.enabledSectionIds.isEmpty && !preferences.enabledSectionIds.contains(section.id) {
                return false
            }
            // Skip red flags section from scoring
            if section.title.contains("Red flags") {
                return false
            }
            return true
        }
        
        guard !enabledSections.isEmpty else { return 0 }
        
        // Calculate average score for each enabled section
        for section in enabledSections {
            var sectionRatings: [Double] = []
            
            for item in section.items {
                // Check if question is enabled (empty set = all enabled)
                if !preferences.enabledQuestionIds.isEmpty && !preferences.enabledQuestionIds.contains(item.id) {
                    continue
                }
                
                // Only count ratings 1-5, exclude N/A (6) and unrated (0)
                if item.programRating > 0 && item.programRating < 6 {
                    sectionRatings.append(item.programRating)
                }
            }
            
            guard !sectionRatings.isEmpty else { continue }
            
            let averageScore = sectionRatings.reduce(0, +) / Double(sectionRatings.count)
            
            // Get stable identifier for weight lookup (title for standard sections, ID for custom)
            let stableId: String
            if section.title.contains("Section A") || section.title.contains("Section B") || 
               section.title.contains("Section C") || section.title.contains("Section D") ||
               section.title.contains("Section E") || section.title.contains("Section F") {
                // Standard section - use title as stable ID
                stableId = section.title
            } else {
                // Custom section - use ID
                stableId = section.id
            }
            
            // Get weight for this section (default to equal weight if not set)
            let weight: Double
            if preferences.sectionWeights.isEmpty {
                // Equal weights for all sections
                weight = 1.0 / Double(enabledSections.count)
            } else {
                // Use custom weight, or equal weight if not specified
                // Try both stableId and section.id for backward compatibility
                weight = preferences.sectionWeights[stableId] ?? 
                         preferences.sectionWeights[section.id] ?? 
                         (1.0 / Double(enabledSections.count))
            }
            
            sectionScores.append((sectionId: stableId, averageScore: averageScore, weight: weight))
        }
        
        guard !sectionScores.isEmpty else { return 0 }
        
        // Normalize weights to sum to 1.0
        let totalWeight = sectionScores.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }
        
        // Calculate weighted average
        let weightedSum = sectionScores.reduce(0) { sum, score in
            let normalizedWeight = score.weight / totalWeight
            return sum + (score.averageScore * normalizedWeight)
        }
        
        // Scale from 0-5 to 0-100
        return weightedSum * 20
    }
    
    // Get enabled sections based on preferences (standard + custom)
    func enabledSections(preferences: UserPreferences) -> [QuestionnaireSection] {
        let allSections = sections + customSections
        return allSections.filter { section in
            // Empty set means all enabled
            if preferences.enabledSectionIds.isEmpty {
                return true
            }
            return !preferences.enabledSectionIds.contains(section.id)
        }
    }
    
    // Get enabled items for a section based on preferences
    func enabledItems(for section: QuestionnaireSection, preferences: UserPreferences) -> [QuestionnaireItem] {
        return section.items.filter { item in
            // Empty set means all enabled
            if preferences.enabledQuestionIds.isEmpty {
                return true
            }
            return preferences.enabledQuestionIds.contains(item.id)
        }
    }
    
    // Calculate average score for a section (0-5)
    private func averageScore(for section: QuestionnaireSection) -> Double {
        let ratings = section.items.compactMap { $0.programRating > 0 ? $0.programRating : nil }
        guard !ratings.isEmpty else { return 0 }
        return ratings.reduce(0, +) / Double(ratings.count)
    }
}

