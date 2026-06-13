//
//  WeightSlider.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI

struct WeightSlider: View {
    let title: String
    @Binding var value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Slider(value: $value, in: 0...100, step: 1)
                .tint(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    WeightSlider(title: "Program Quality", value: .constant(30.0), color: .blue)
}



