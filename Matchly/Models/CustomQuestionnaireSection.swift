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

