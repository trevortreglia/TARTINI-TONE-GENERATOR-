(
// ==============================
// TARTINI TONE GENERATOR
// ==============================
// A SuperCollider tool for exploring primary, difference, and summation tones.
//
//// HOW TO USE:
// 1. Go to the top menu: Language → Evaluate File.
// 2. A GUI window will appear.
// 3. To stop sound at any time: Go to Language → Stop (or press Cmd+.).

// Author: Trevor Treglia (2025)
// License: MIT

// ==============================

~parseTone = { |str, base=440|
    var val;
    if (str.contains("/")) {
        var parts = str.split($/).collect(_.asFloat);
        if (parts[1] == 0) { val = base } { val = base * (parts[0] / parts[1]) };
    } {
        val = str.asFloat;
        if (val.isNaN or: { val <= 0 }) { val = base };
    };
    val;
};

~approxRatio = { |value, base|
    var ratio = value / base;
    var maxDen = 64;
    var num = 1;
    var den = 1;
    var err = 1e9;
    maxDen.do { |d|
        var n = (ratio * (d+1)).round;
        var approx = n / (d+1);
        var e = (approx - ratio).abs;
        if (e < err) { err = e; num = n; den = d+1 };
    };
    num.asInteger.asString ++ "/" ++ den.asInteger.asString
};

~computeTones = { |f1, f2, base|
    var names = [
        "Primary 1 (f₁)","Primary 2 (f₂)",
        "Difference 1 (f₂ − f₁)","Difference 2 (2f₁ − f₂)","Difference 3 (3f₁ − 2f₂)",
        "Summation 1 (f₁ + f₂)","Summation 2 (2f₁ + f₂)","Summation 3 (f₁ + 2f₂)",
        "Summation 4 (3f₁ + f₂)","Summation 5 (2f₁ + 2f₂)","Summation 6 (f₁ + 3f₂)"
    ];
    var freqs = [
        f1, f2, (f2 - f1).abs, 2*f1 - f2, 3*f1 - 2*f2,
        f1 + f2, 2*f1 + f2, f1 + 2*f2, 3*f1 + f2, 2*f1 + 2*f2, f1 + 3*f2
    ];
    freqs.collect { |f, i| [names[i], f, ~approxRatio.(f, base)] }
};

SynthDef(\tartiniTones, { |out=0, freqs=#[440,0,0,0,0,0,0,0,0,0,0], amps=#[1,0,0,0,0,0,0,0,0,0,0], waveform=0, timbre=10, cutoff=20000, mute=1|
    var osc = Mix.fill(11, { |i|
        var tone = freqs[i].clip(20, 20000);
        var a = Lag.kr(amps[i], 0.05);
        var maxHarm = (SampleRate.ir / (2 * tone)).clip(1, 50);
        var wave = Select.ar(waveform, [
            SinOsc.ar(tone),
            VarSaw.ar(tone, 0, 0.5),
            Blip.ar(tone, timbre.clip(1, maxHarm))
        ]);
        Pan2.ar(wave, (i/11.0-0.5)*0.8, a)
    });
    Out.ar(out, LPF.ar(osc, cutoff) * 0.3 * (1 - mute));
}).add;

s.waitForBoot({
    var win = Window("TARTINI TONE GENERATOR", Rect(100,100,600,650)).front.alwaysOnTop_(true);
    var baseBox, tone1Box, tone2Box, wfMenu, cutoffSlider, resetButton, muteButton;
    var checkboxes, freqLabels;
    var synth;
    var baseFreq=440, tone1Str="1/1", tone2Str="3/2", waveform=0, cutoff=20000, mute=0, timbre=10, amps=[1,1]++Array.fill(9,0);
    var getFreqs, update;
    var codeFont = Font("Monaco", 14);
    var bgColor = Color.gray(0.15);
    var textColor = Color.white;
    var separatorLine = nil;

    checkboxes = Array.newClear(11);
    freqLabels = Array.newClear(11);

    getFreqs = {
        var f1 = ~parseTone.(tone1Str, baseFreq);
        var f2 = ~parseTone.(tone2Str, baseFreq);
        ~computeTones.(f1, f2, baseFreq)
    };

    update = {
        var allTones = getFreqs.();
        var seen = Set.new;
        var visibleIndex = 0;
        var y, bg, buttonsY, totalWidth, startX;

        checkboxes.do(_.remove);
        freqLabels.do(_.remove);
        checkboxes.clear;
        freqLabels.clear;

        allTones.do { |tone, i|
            var freq = tone[1];
            var rounded = freq.round(0.1);
            var isAudible = freq >= 20 and: { freq <= 20000 };
            var isDup = seen.includes(rounded);
            if (isDup.not and: isAudible) {
                seen.add(rounded);
                y = 280 + (visibleIndex * 30);
                bg = CompositeView(win, Rect(50, y, 500, 25));
                checkboxes[i] = CheckBox(bg, Rect(5,3,20,20)).value_(amps[i]).enabled_(true).action_({ amps[i] = checkboxes[i].value; synth.set(\amps, amps) });
                freqLabels[i] = StaticText(bg, Rect(35,3,450,20))
                    .string_(tone[0] ++ " : " ++ tone[2] ++ " : " ++ tone[1].round(0.1).asString)
                    .stringColor_(textColor)
                    .font_(codeFont);
                visibleIndex = visibleIndex + 1;
            };
        };

        // separator
        if(separatorLine.notNil) { separatorLine.bounds = Rect(40, 270, win.bounds.width - 80, 1) }
        { separatorLine = View(win, Rect(40, 270, win.bounds.width - 80, 1)); separatorLine.background = Color.gray(0.6) };

        // center buttons
        buttonsY = 280 + (visibleIndex * 30) + 20;
        totalWidth = 210;
        startX = (win.bounds.width - totalWidth) / 2;
        muteButton.bounds = Rect(startX, buttonsY, 100, 30);
        resetButton.bounds = Rect(startX + 110, buttonsY, 100, 30);

        synth.set(\freqs, allTones.collect(_[1]), \amps, amps, \waveform, waveform, \timbre, timbre, \cutoff, cutoff, \mute, mute);
        win.refresh;
    };

    // GUI
    win.background = bgColor;
    StaticText(win, Rect(250,10,100,20)).string_("1/1").align_(\center).font_(codeFont).stringColor_(textColor);
    baseBox = NumberBox(win, Rect(250,35,100,20)).value_(baseFreq).font_(codeFont).action_({ baseFreq = baseBox.value; update.() });
    StaticText(win, Rect(250,70,100,20)).string_("FREQUENCIES:").align_(\center).font_(codeFont).stringColor_(textColor);
    tone1Box = TextField(win, Rect(170,95,100,20)).string_(tone1Str).font_(codeFont).action_({ tone1Str = tone1Box.string; update.() });
    tone2Box = TextField(win, Rect(330,95,100,20)).string_(tone2Str).font_(codeFont).action_({ tone2Str = tone2Box.string; update.() });
    StaticText(win, Rect(250,130,100,20)).string_("OSCILLATOR:").align_(\center).font_(codeFont).stringColor_(textColor);
    wfMenu = PopUpMenu(win, Rect(200,155,200,20)).items_(["SINE","SAW","BAND-LIMITED HARMONIC"]).value_(waveform).font_(codeFont).action_({ waveform = wfMenu.value; update.() });
    StaticText(win, Rect(230,185,140,20)).string_("LOWPASS CUTOFF:").align_(\center).font_(codeFont).stringColor_(textColor);
    cutoffSlider = Slider(win, Rect(150,210,300,20)).orientation_(\horizontal).value_(cutoff.explin(100,20000,0,1))
        .action_({ cutoff = cutoffSlider.value.linexp(0,1,100,20000); update.() });

    muteButton = Button(win, Rect(270,240,100,30)).states_([["MUTE", 1], ["UNMUTE", 0]]).font_(codeFont).value_(mute).action_({ mute = muteButton.value; update.() });
    resetButton = Button(win, Rect(380,240,100,30)).states_([["RESET",0]]).font_(codeFont).action_({
        baseFreq = 440; tone1Str = "1/1"; tone2Str = "3/2";
        waveform = 0; cutoff = 20000; mute = 0; timbre = 10;
        amps = [1,1] ++ Array.fill(9,0);
        baseBox.value = baseFreq; tone1Box.string = tone1Str; tone2Box.string = tone2Str;
        wfMenu.value = waveform; cutoffSlider.value = cutoff.explin(100,20000,0,1); muteButton.value = mute;
        update.();
    });

    win.onClose = { mute = 1; synth.set(\mute, mute); synth.free };
    synth = Synth(\tartiniTones, [\freqs, getFreqs.().collect(_[1]), \amps, amps, \waveform, waveform, \timbre, timbre, \cutoff, cutoff, \mute, mute]);
    update.();
});
)