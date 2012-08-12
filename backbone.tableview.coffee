###
TableView
---------
###

###
A View that can be used with any backbone collection, and draws a table with it.
Optionally it supports pagination, search, and any number of filters
("inputs", "button", "option"). Eg (Users is a Backbone.Collection):

    class UserTableView extends Backbone.TableView
        title: "My Users Table"
        collection: new Users()
        columns:
            name:
                header: "My Name"
            type:
                header: "Type"
            last_login:
                header: "Last Login Time"
                draw: (model) ->
                    new Date(model.get 'time')
            description:
                header: "Description"
                nosort: true
                draw: (model) ->
                    some_weird_formatting_function(model.get('some_text'))
        pagination: true
        search:
            query: "name"
            detail: "Search by Name"
        filters:
            from:
                type: "input"
                className: "date"
                init: new Date()
                get: (val) ->
                    ... process the date val ...
###
class Backbone.TableView extends Backbone.View
    tagName: "div"
    titleTemplate: _.template "<h2><%= model %></h2>"
    searchTemplate: _.template """
        <input type="text" class="search-query pull-right" placeholder="<%= model.detail || model %>"></input>
    """
    paginationTemplate: _.template """
        <ul class="pager">
            <li class="pager-prev">
                <a href="javascript:void(0)">&larr; Prev</a>
            </li>
            <span class="badge badge-info page">1</span>
            <li class="pager-next">
                <a href="javascript:void(0)">Next &rarr;</a>
            </li>
        </ul>
    """
    dataTemplate: _.template """
        <% _.each(collection.models, function (row) { %>
            <tr>
                <% _.each(columns, function (col, name) { %>
                    <td class="<%= col.className || "" %>">
                        <%= col.draw ? col.draw(row) : row.get(name) %>
                    </td>
                <% }) %>
            </tr>
        <% }) %>
        <% if (collection.models.length == 0) { %>
            <tr>
                <td colspan="10"><%= empty %></td>
            </tr>
        <% } %>
    """
    template: _.template """
        <div class="row-fluid">
            <div class="span2">
                <%= title %>
            </div>

            <div class="filters controls pagination-centered span8">
            </div>

            <div class="span2">
                <%= search %>
            </div>
        </div>

        <table class="table table-striped table-bordered">
            <thead>
                <tr>
                    <% _.each(columns, function (col, key) { %>
                        <th abbr="<%= key || col %>" class="<%= !col.nosort && "sorting" %> <%= col.className || "" %>">
                            <%= col.header || col %>
                        </th>
                    <% }) %>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td colspan="10"><%= empty %></td>
                </tr>
            </tbody>
        </table>

        <%= pagination %>
    """
    events:
        "keypress .search-query": "updateSearchOnEnter"
        "click    .pager-prev":   "prevPage"
        "click    .pager-next":   "nextPage"
        "click    th":            "toggleSort"

    # Binds the collection update event for rendering
    initialize: ->
        @collection.on "reset", @renderData
        @data = @options.initialData or @initialData or {}
        @data.page = @options.page or @page or 1
        @data.size = @options.size or @size or 10
        return @

    # Set data and update collection
    setData: (id, val) =>
        @data[id] = val
        @update()

    # Creates a filter from a filter config definition
    createFilter: (name, filter) =>
        switch filter.type
            when "button"
                return new ButtonFilter
                    id: name
                    init: filter.init or "false"
                    toggle: filter.toggle or "true"
                    filterClass: filter.className or ""
                    setData: @setData
            when "input"
                return new InputFilter
                    id: name
                    init: filter.init or ""
                    className: "input-prepend inline"
                    filterClass: filter.className or ""
                    get: filter.get or _.identity
                    setData: @setData
        # For custom filters, we just provide the setData function
        filter.setData = @setData
        return filter

    # Update collection only if event was trigger by an enter
    updateSearchOnEnter: (e) =>
        if e.keyCode == 13
            val = e.currentTarget.value
            if val
                @data[@search.query or "q"] = val
            else
                delete @data[@search.query or "q"]
            @update()
        return @

    # Update the collection given all the options/filters
    update: =>
        @collection.fetch data: @data
        return @

    # Render the collection in the tbody section of the table
    renderData: =>
        $("tbody", @$el).html @dataTemplate
            collection: @collection
            columns:    @columns
            empty:      @empty or "No records to show"
        return @

    # Go to the previous page in the collection
    prevPage: =>
        if @data.page > 1
            @data.page = @data.page - 1
            $(".page", @$el).html @data.page
            @update()

    # Go to the next page in the collection
    nextPage: =>
        # Since we don't have a collection count, for now we use the size of
        # the last GET as an heuristic to limit the use of nextPage
        if @collection.length == @data.size
            @data.page = @data.page + 1
            $(".page", @$el).html @data.page
            @update()

    # Toggle/Select sort column and direction, and update table accodingly
    toggleSort: (e) =>
        el = e.currentTarget
        cl = el.className
        if cl.indexOf("sorting_desc") >= 0
            @data.sort_dir = "asc"
            cl = "sorting_asc"
        else if cl.indexOf("sorting") >= 0 or cl.indexOf("sorting_asc") >= 0
            @data.sort_dir = "desc"
            cl = "sorting_desc"
        else
            return @
        $("th.sorting_desc, th.sorting_asc", @$el).removeClass("sorting_desc sorting_asc")
        $(el, @$el).addClass(cl)
        @data.sort_col = el.abbr
        @update()

    # Apply a template to a model and return the result (string), or empty
    # string if model is false/undefined
    applyTemplate: (template, model) ->
        (model and template model: model) or ""

    # Render skeleton of the table, creating filters and other additions,
    # and trigger an update of the collection
    render: =>
        @$el.html @template
            columns:    @columns
            empty:      @empty or ""
            title:      @applyTemplate @titleTemplate,      @title
            search:     @applyTemplate @searchTemplate,     @search
            pagination: @applyTemplate @paginationTemplate, @pagination

        @filters = _.map(@filters, (filter, name) => @createFilter(name, filter))
        filtersDiv = $(".filters", @$el)
        _.each @filters, (filter) ->
            filtersDiv.append filter.render().el
            filtersDiv.append " "
        @update()

###
Filters
-------
###

class Filter extends Backbone.View
    tagName: "div"
    className: "inline"

    initialize: ->
        @id = @options.id
        @setData = @options.setData

    # Helper function to prettify names (eg. hi_world -> Hi World)
    prettyName: (str) ->
        str.charAt(0).toUpperCase() + str.substring(1).replace(/_(\w)/g, (match, p1) -> " " + p1.toUpperCase())

    render: =>
        @options.name = @prettyName(@id)
        @$el.html @template @options
        return @

class InputFilter extends Filter
    template: _.template """
        <span class="add-on"><%= name %></span><input type="text" class="filter <%= filterClass %>" value="<%= init %>"></input>
    """
    events:
        "change .filter": "update"

    update: (e) =>
        @setData @id, @options.get e.currentTarget.value

class ButtonFilter extends Filter
    template: _.template """
        <button type="button" class="filter btn <%= filterClass %>" data-toggle="button"><%= name %></button>
    """
    events:
        "click .filter": "update"

    initialize: ->
        super
        @values = [@options.init, @options.toggle]
        @current = 0

    update: =>
        @current = 1 - @current
        @setData @id, @values[@current]
