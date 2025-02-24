local utils = require("gitblame.utils")
local M = {}

---@param callback fun(is_ignored: boolean)
function M.check_is_ignored(callback)
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then
        return true
    end

    utils.start_job("git check-ignore " .. vim.fn.shellescape(filepath), {
        on_exit = function(code)
            callback(code ~= 1)
        end,
    })
end

---@param sha string
---@param remote_url string
---@return string
local function get_commit_path(sha, remote_url)
    local domain = string.match(remote_url, ".*git%@(.*)%:.*")
        or string.match(remote_url, "https%:%/%/.*%@(.*)%/.*")
        or string.match(remote_url, "https%:%/%/(.*)%/.*")

    if domain and domain:lower() == "bitbucket.org" then
        return "/commits/" .. sha
    end

    return "/commit/" .. sha
end

---@param remote_url string
---@return string
local function get_repo_url(remote_url)
    local domain, path = string.match(remote_url, ".*git%@(.*)%:(.*)%.git")
    if domain and path then
        return "https://" .. domain .. "/" .. path
    end

    local url = string.match(remote_url, ".*git%@(.*)%.git")
    if url then
        return "https://" .. url
    end

    local https_url = string.match(remote_url, "(https%:%/%/.*)%.git")
    if https_url then
        return https_url
    end

    domain, path = string.match(remote_url, ".*git%@(.*)%:(.*)")
    if domain and path then
        return "https://" .. domain .. "/" .. path
    end

    url = string.match(remote_url, ".*git%@(.*)")
    if url then
        return "https://" .. url
    end

    https_url = string.match(remote_url, "(https%:%/%/.*)")
    if https_url then
        return https_url
    end

    return remote_url
end

---@param remote_url string
---@param branch string
---@param filepath string
---@param line_number number?
---@return string
local function get_file_url(remote_url, branch, filepath, line_number)
    local file_path = "/blob/" .. branch .. "/" .. filepath

    local repo_url = get_repo_url(remote_url)

    if line_number == nil then
        return repo_url .. file_path
    else
        return repo_url .. file_path .. "#L" .. line_number
    end
end

---@param callback fun(branch_name: string)
local function get_current_branch(callback)
    if not utils.get_filepath() then
        return
    end
    local command = utils.make_local_command("git branch --show-current")

    utils.start_job(command, {
        on_stdout = function(url)
            if url and url[1] then
                callback(url[1])
            else
                callback("")
            end
        end,
    })
end

---@param filepath string
---@param line_number number?
---@param callback fun(url: string)
function M.get_file_url(filepath, line_number, callback)
    M.get_repo_root(function(root)
        local relative_filepath = string.sub(filepath, #root + 2)

        get_current_branch(function(branch)
            M.get_remote_url(function(remote_url)
                local url = get_file_url(remote_url, branch, relative_filepath, line_number)
                callback(url)
            end)
        end)
    end)
end

---@param sha string
---@param remote_url string
---@return string
function M.get_commit_url(sha, remote_url)
    local commit_path = get_commit_path(sha, remote_url)

    local repo_url = get_repo_url(remote_url)
    return repo_url .. commit_path
end

---@param filepath string
---@param line_number number?
function M.open_file_in_browser(filepath, line_number)
    M.get_file_url(filepath, line_number, function(url)
        utils.launch_url(url)
    end)
end

---@param sha string
function M.open_commit_in_browser(sha)
    M.get_remote_url(function(remote_url)
        local commit_url = M.get_commit_url(sha, remote_url)
        utils.launch_url(commit_url)
    end)
end

---@param callback fun(url: string)
function M.get_remote_url(callback)
    if not utils.get_filepath() then
        return
    end
    local remote_url_command = utils.make_local_command("git config --get remote.origin.url")

    utils.start_job(remote_url_command, {
        on_stdout = function(url)
            if url and url[1] then
                callback(url[1])
            else
                callback("")
            end
        end,
    })
end

---@param callback fun(repo_root: string)
function M.get_repo_root(callback)
    if not utils.get_filepath() then
        return
    end
    local command = utils.make_local_command( "git rev-parse --show-toplevel")

    utils.start_job(command, {
        on_stdout = function(data)
            callback(data[1])
        end,
    })
end

return M
