local ht = require('haskell-tools')
local hoogle_web = require('haskell-tools.hoogle.web')
local hoogle_local = require('haskell-tools.hoogle.local')
local deps = require('haskell-tools.deps')
local lsp_util = vim.lsp.util

local M = {
  handler = nil
}

local function setup_handler(opts)
  if opts.mode == 'telescope-web' then
    M.handler = hoogle_web.telescope_search
  elseif opts.mode == 'telescope-local' then
    M.handler = hoogle_local.telescope_search
  elseif opts.mode == 'browser' then
    M.handler = hoogle_web.browser_search
  elseif opts.mode == 'auto' then
    if not deps.has_telescope() then
      M.handler = hoogle_web.browser_search
    elseif hoogle_local.has_hoogle() then
      M.handler = hoogle_local.telescope_search
    else
      M.handler = hoogle_web.telescope_search
    end
  end
end

local function setup_goto_definition_fallback()
  -- TODO
end

local function get_signature_from_markdown(docs)
  local func_name = vim.fn.expand('<cword>')
  local full_sig = docs:match('```haskell\n' .. func_name .. ' :: ([^```]*)')
  return full_sig
    and full_sig:gsub('\n', ' ') -- join lines
        :gsub('forall .*%.%s', '') -- hoogle cannot search for `forall a.`
    or func_name -- Fall back to value under cursor
end

local function on_lsp_hoogle_signature(options)
  return function(_, result, _, _)
    if not (result and result.contents) then
      vim.notify('hoogle: No information available')
      return
    end
    local signature = get_signature_from_markdown(result.contents.value)
    if signature and signature ~= '' then
      ht.hoogle.handler(signature, options)
    end
  end
end

local function lsp_hoogle_signature(options)
  local params = lsp_util.make_position_params()
  return vim.lsp.buf_request(0, 'textDocument/hover', params, on_lsp_hoogle_signature(options))
end

function M.hoogle_signature(options)
  local clients = vim.lsp.get_active_clients { bufnr = vim.api.nvim_get_current_buf() }
  if #clients > 0 then
    lsp_hoogle_signature(options)
  else
    local cword = vim.fn.expand('<cword>')
    ht.hoogle.handler(cword, options)
  end
end

function M.setup()
  hoogle_web.setup()
  hoogle_local.setup()
  local opts = ht.config.options.tools.hoogle
  setup_handler(opts)
  if opts.goToDefinitionFallback then
    setup_goto_definition_fallback()
  end
end

return M
