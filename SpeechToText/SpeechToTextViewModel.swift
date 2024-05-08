//
//  SpeechToTextViewModel.swift
//  SpeechToText
//
//  Created by Jesus Cruz Suárez on 8/05/24.
//

import Foundation
import AVFoundation
import Speech

public class SpeechToTextViewModel: ObservableObject {
    @Published public var transcript: String = ""
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer? = nil
    
    public init(localeIdentifier: String = Locale.current.identifier) {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        
        Task(priority: .background) {
            do {
                guard recognizer != nil else {
                    throw RecognizerError.nilRecognizer
                }
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                print(error)
            }
        }
    }
    
    deinit {
        print("Entro a deInit")
        reset()
    }
    
    /// Reset the speech recognizer.
    func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    /**
     Begin transcribing audio.
     Creates a `SFSpeechRecognitionTask` that transcribes speech to text until you call `stopTranscribing()`.
     The resulting transcription is continuously written to the published `transcript` property.
    */
    public func transcribe() {
        DispatchQueue(label: "Speech Recognizer Queue", qos: .userInteractive).async { [weak self] in
            guard let self = self, let recognizer = self.recognizer, recognizer.isAvailable else {
                print(RecognizerError.recognizerIsUnavailable)
                return
            }
                   
            do {
                let (audioEngine, request) = try Self.prepareEngine()
                self.audioEngine = audioEngine
                self.request = request
                
                self.task = recognizer.recognitionTask(with: request) { result, error in
                    /*
                        Amigos mios por aqui creo que esta el error, cuando se ejecuta el stopTranscribing()
                        
                        Cosas que detecte:
                        1. Al pausar manualmente cuando ya detecto voz lanza un error, pero no es siempre lo cual es muy raro
                        2. Al pausar parece que todo este bloque se esta volviendo a ejecutar porque en la consola el result se muestra dos veces mas una con el valor que ya se tenia y una ultima vacia que es la que esta ocasionando que se borre el valor
                     
                        Conclusion: Estoy cansado jefe.
                     */
                    let receivedFinalResult = result?.isFinal ?? false
                    let receivedError = error != nil // != nil mean there's error (true)
                        
                    if receivedFinalResult || receivedError {
                        audioEngine.stop()
                        audioEngine.inputNode.removeTap(onBus: 0)
                    }
                           
                    if let result = result {
                        print("result \(result.bestTranscription.formattedString)")
                        self.speak(result.bestTranscription.formattedString)
                    }
                }
            } catch {
                self.reset()
                print(error)
            }
        }
    }
           
    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
               
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
               
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
               
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
               
        return (audioEngine, request)
    }
    
    /// Stop transcribing audio.
    public func stopTranscribing() {
        reset()
    }
    
    private func speak(_ message: String) {
        transcript = message
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
