//
//  ContentView.swift
//  SpeechToText
//
//  Created by Jesus Cruz Suárez on 8/05/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = SpeechToTextViewModel()
    @State var title:String = "Start Recording"
    @State var isRecording:Bool = false
    @State var color:Color = .cyan
       
    var body: some View {
        VStack {
            Spacer()
            Text(viewModel.transcript)
            Text("\((isRecording == false) ? "":((viewModel.transcript == "") ? "Speak Now": viewModel.transcript))")
            Spacer()
            Button("\(title)") {
                isRecording.toggle()
                if  isRecording {
                    viewModel.transcribe()
                    title = "Stop Recording"
                    color = .red
                }else{
                    viewModel.stopTranscribing()
                    title = "Start Recording"
                    color = .cyan
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
