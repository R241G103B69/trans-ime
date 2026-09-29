-- rime.lua
-- TransType Translation Filter for Rime (Squirrel / Weasel / Fcitx-Rime)

local dict = {
    ["你好"] = { "Hello", "Hi", "Greetings" },
    ["谢谢"] = { "Thank you", "Thanks", "Appreciate it" },
    ["再见"] = { "Goodbye", "See you later", "Bye" },
    ["开会"] = { "Have a meeting", "Hold a meeting", "Meet" },
    ["会议室"] = { "Conference room", "Meeting room", "Boardroom" },
    ["方案"] = { "Solution", "Proposal", "Plan" },
    ["设计"] = { "Design", "Architecture" },
    ["开发"] = { "Development", "Develop" },
    ["测试"] = { "Test", "Verify", "Validate" },
    ["发布"] = { "Release", "Deploy", "Launch" },
    ["问题"] = { "Issue", "Problem", "Bug" },
    ["解决"] = { "Resolve", "Fix", "Solve" },
    ["有空"] = { "Available", "Free", "Have time" },
    ["收到"] = { "Got it", "Acknowledged", "Received" },
    ["反馈"] = { "Feedback", "Input" },
    ["截止日期"] = { "Deadline", "Due date" },
    ["今天下午三点在会议室开会"] = {
        "Meeting in the conference room at 3 PM today.",
        "We will have a meeting in the conference room at 3:00 PM this afternoon.",
        "Let's meet in the conference room at 3pm today."
    },
    ["请问您明天下午是否有空开个会讨论项目进展"] = {
        "Could you please let me know if you are available tomorrow afternoon for a meeting to discuss project progress?",
        "Are you free to jump on a quick call tomorrow afternoon to go over project progress?"
    }
}

function trans_filter(input, env)
    for cand in input:iter() do
        local zh = cand.text
        local translations = dict[zh]
        if translations then
            -- Yield the English translations as primary candidates!
            for i, en in ipairs(translations) do
                local c = Candidate("trans", cand.start, cand._end, en, " [" .. zh .. "]")
                c.quality = cand.quality + 10 - i
                yield(c)
            end
        else
            -- If no direct translation in dictionary, yield original candidate
            yield(cand)
        end
    end
end

function trans_translator(input, seg)
    -- Dedicated translator for special trigger prefix e.g. "e" + pinyin or "t"
    -- Example: typing 'enihao' directly yields English candidates
    if string.sub(input, 1, 1) == "e" then
        local pinyin = string.sub(input, 2)
        -- Can match pinyin directly
    end
end
