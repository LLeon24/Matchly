//
//  CustomQuestionnaireSection.swift
//  Matchly
//
//  Created on 11/14/25.
//

import Foundation

struct CustomQuestionnaireSection: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var items: [CustomQuestionnaireItem]
    
    init(id: String = UUID().uuidString, title: String, items: [CustomQuestionnaireItem] = []) {
        self.id = id
        self.title = title
        self.items = items
    }
}

struct CustomQuestionnaireItem: Codable, Identifiable, Hashable {
    let id: String
    var question: String
    
    init(id: String = UUID().uuidString, question: String) {
        self.id = id
        self.question = question
    }
}

// MARK: - Resilient decoding
// Missing keys fall back to defaults so decoding never throws (see Program.swift).

extension CustomQuestionnaireSection {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.items = try container.decodeIfPresent([CustomQuestionnaireItem].self, forKey: .items) ?? []
    }
}

extension CustomQuestionnaireItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
    }
}

