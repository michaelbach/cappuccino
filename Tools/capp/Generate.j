/*
 * Generate.j
 * capp
 *
 * Created by Francisco Tolmasky.
 * Copyright 2009, 280 North, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import "Configuration.j"

/* var OS = require("os"),
    SYSTEM = require("system"),
    FILE = require("file"); */
var OBJJ = require("objj-runtime"),
    stream = require("objj-runtime").term.stream;

parser = new (require("objj-runtime").parser.Parser)();

// FIXME: lots of chaining using narwhals path wrapper, this file might still be broken
var fs = require("fs");
var node_path = require("path");
var child_process = require("child_process");
var jake = require("objj-jake");
// FIXME: removing command line options for now

parser.usage("DESTINATION_DIRECTORY");

parser.help("Generate a Cappuccino project or Frameworks directory");

parser.option("-t", "--template", "template")
    .set()
    .def("Application")
    .help("Selects a project template to use (default: Application).");

parser.option("-f", "--frameworks", "justFrameworks")
    .set(true)
    .help("Only generate or update Frameworks directory.");

parser.option("-F", "--framework", "framework", "frameworks")
    .def([])
    .push()
    .help("Additional framework to copy/symlink (default: Objective-J, Foundation, AppKit)");

parser.option("-T", "--theme", "theme", "themes")
    .def([])
    .push()
    .help("Additional Theme to copy/symlink into Resource (default: nothing)");

parser.option("--no-frameworks", "noFrameworks")
    .set(true)
    .help("Don't copy any default frameworks (can be overridden with -F)");

parser.option("--symlink", "symlink")
    .set(true)
    .help("Creates a symlink to each framework instead of copying.");

parser.option("--build", "useCappBuild")
    .set(true)
    .help("Uses frameworks in the $CAPP_BUILD.");

parser.option("-l")
    .action(function(o) { o.symlink = o.useCappBuild = true; })
    .help("Enables both the --symlink and --build options.");

parser.option("--force", "force")
    .set(true)
    .help("Overwrite update existing frameworks.");

parser.option("--noconfig", "noconfig")
    .set(true)
    .help("Use the default configuration, ignore your configuration.");

parser.option("--list-templates", "listTemplates")
    .set(true)
    .help("Lists available templates.");

parser.option("--list-frameworks", "listFrameworks")
    .set(true)
    .help("Lists available frameworks.");

parser.helpful();

// FIXME: better way to do this:
/* var CAPP_HOME = require("narwhal/packages").catalog["cappuccino"].directory,
    templatesDirectory = node_path.join(CAPP_HOME, "lib", "capp", "Resources", "Templates"); */

var templatesDirectory = "/Users/alfred/Developer/cappuccino/Tools/capp/Resources/Templates";

function gen(/*va_args*/)
{
    console.log("in gen: " + arguments);
    var args = ["capp gen"].concat(Array.prototype.slice.call(arguments));
    debugger;
    var options = parser.parse(args, null, null, true);

    console.log(options);

    if (options.args.length > 1)
    {
        parser.printUsage(options);
        process.exit(1);
    }
    console.log("a");

    if (options.listTemplates)
    {
        listTemplates();
        return;
    }
    console.log("b");

    if (options.listFrameworks)
    {
        listFrameworks();
        return;
    }
    console.log("c");

    var destination = options.args[0];

    if (!destination)
    {
        if (options.justFrameworks)
            destination = ".";

        else
        {
            parser.printUsage(options);
            process.exit(1);
        }
    }
    var sourceTemplate = null;

    if (node_path.isAbsolute(options.template))
        sourceTemplate = options.template;
    else
        sourceTemplate = node_path.join(templatesDirectory, options.template);

    console.log(sourceTemplate);
    if (!fs.lstatSync(sourceTemplate).isDirectory())
    {
        stream.print(colorize("Error: ", "red") + "The template " + logPath(sourceTemplate) + " cannot be found. Available templates are:");
        listTemplates();
        process.exit(1);
    }
    console.log("d");
    var configFile = node_path.join(sourceTemplate, "template.config"),
        config = {};
    console.log(configFile);
    if (fs.existsSync(configFile))
        config = JSON.parse(fs.readFileSync(configFile, { encoding: "utf8" }));
        //config = JSON.parse(FILE.read(configFile, { charset:"UTF-8" }));
    console.log("e");
    debugger;
    var destinationProject = destination,
        configuration = options.noconfig ? [Configuration defaultConfiguration] : [Configuration userConfiguration],
        frameworks = options.frameworks,
        themes = options.themes;

    console.log("f");

    if (!options.noFrameworks)
        frameworks.push("Objective-J", "Foundation", "AppKit");

    console.log("before if");

    if (options.justFrameworks)
    {
        createFrameworksInFile(frameworks, destinationProject, options.symlink, options.useCappBuild, options.force);
        createThemesInFile(themes, destinationProject, options.symlink, options.force);
    }
    else if (!fs.existsSync(destinationProject))
    {
        function copyRecursiveSync(src, dest) {
            var exists = fs.existsSync(src);
            var stats = exists && fs.statSync(src);
            var isDirectory = exists && stats.isDirectory();
            if (isDirectory) {
                fs.mkdirSync(dest, { recursive: true });
                fs.readdirSync(src).forEach(function(childItemName) {
                    copyRecursiveSync(node_path.join(src, childItemName), node_path.join(dest, childItemName));
            });
            } else {
            fs.copyFileSync(src, dest);
            }
        };

        console.log("before copy: " + sourceTemplate + " " + destinationProject);
        // FIXME???
        copyRecursiveSync(sourceTemplate, destinationProject);

        var files = (new jake.FileList(node_path.join(destinationProject, "**", "*"))).toArray(),
            count = files.length,
            name = node_path.basename(destinationProject),
            orgIdentifier = [configuration valueForKey:@"organization.identifier"] || "";

        [configuration setTemporaryValue:name forKey:@"project.name"];
        [configuration setTemporaryValue:orgIdentifier + '.' +  toIdentifier(name) forKey:@"project.identifier"];
        [configuration setTemporaryValue:toIdentifier(name) forKey:@"project.nameasidentifier"];

        for (var index = 0; index < count; ++index)
        {
            var path = files[index];

            if (fs.lstatSync(path).isDirectory())
                continue;

            if (node_path.basename(path) === ".DS_Store")
                continue;

            // Don't do this for images.
            if ([".png", ".jpg", ".jpeg", ".gif", ".tif", ".tiff"].indexOf(node_path.extname(path).toLowerCase()) !== -1)
                continue;

            try
            {
                var contents = fs.readFileSync(path, { encoding: "utf8" }),
                //var contents = FILE.read(path, { charset : "UTF-8" }),
                    key = null,
                    keyEnumerator = [configuration keyEnumerator];

                function escapeRegex(string) {
                    return string.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
                }                       

                while ((key = [keyEnumerator nextObject]) !== nil)
                    contents = contents.replace(new RegExp("__" + escapeRegex(key) + "__", 'g'), [configuration valueForKey:key]);

                fs.writeFileSync(path, contents, { encoding: "utf8" });
                //FILE.write(path, contents, { charset: "UTF-8"});
            }
            catch (anException)
            {
                warn("An error occurred (" + anException.toString() + ") while applying the " + (options.noconfig ? "default" : "user") + " configuration to: " + logPath(path));
            }
        }

        var frameworkDestination = destinationProject;

        if (config.FrameworksPath)
            frameworkDestination = node_path.join(frameworkDestination, config.FrameworksPath);

        createFrameworksInFile(frameworks, frameworkDestination, options.symlink, options.useCappBuild);

        var themeDestination = destinationProject;

        if (themes.length)
            createThemesInFile(themes, themeDestination, options.symlink);
    }

    else
    {
        fail("The directory " + node_path.resolve(destinationProject) + " already exists.");
    }

    executePostInstallScript(destinationProject);
}

function createFrameworksInFile(/*Array*/ frameworks, /*String*/ aFile, /*Boolean*/ symlink, /*Boolean*/ build, /*Boolean*/ force)
{
    var destination = node_path.path(node_path.resolve(aFile));

    if (!destination.isDirectory())
        fail("Cannot create Frameworks. The directory does not exist: " + destination);

    var destinationFrameworks = destination.join("Frameworks"),
        destinationDebugFrameworks = destination.join("Frameworks", "Debug");

    stream.print("Creating Frameworks directory in " + logPath(destinationFrameworks) + "...");

    //destinationFrameworks.mkdirs(); // redundant
    destinationDebugFrameworks.mkdirs();

    if (build)
    {
        if (!(process.env["CAPP_BUILD"]))
            fail("$CAPP_BUILD must be defined to use the --build or -l option.");

        var builtFrameworks = process.env["CAPP_BUILD"],
            sourceFrameworks = node_path.join(builtFrameworks, "Relesase"),
            sourceDebugFrameworks = node_path.join(builtFrameworks, "Debug");

        frameworks.forEach(function(framework)
        {
            installFramework(sourceFrameworks.join(framework), destinationFrameworks.join(framework), force, symlink);
            installFramework(sourceDebugFrameworks.join(framework), destinationDebugFrameworks.join(framework), force, symlink);
        });
    }
    else
    {
        // Frameworks. Search frameworks paths
        frameworks.forEach(function(framework)
        {
            // Need a special case for Objective-J
            if (framework === "Objective-J")
            {
                // Objective-J. Take from OBJJ_HOME.
                var objjHome = OBJJ.OBJJ_HOME,
                    objjPath = node_path.join(objjHome, "Frameworks", "Objective-J"),
                    objjDebugPath = node_path.join(objjHome, "Frameworks", "Debug", "Objective-J");

                installFramework(objjPath, destinationFrameworks.join("Objective-J"), force, symlink);
                installFramework(objjDebugPath, destinationDebugFrameworks.join("Objective-J"), force, symlink);

                return;
            }

            var found = false;

            for (var i = 0; i < OBJJ.objj_frameworks.length; i++)
            {
                var sourceFramework = node_path.join(OBJJ.objj_frameworks[i], framework);                
                
                if (fs.lstatSync(sourceFramework).isDirectory())
                {
                    installFramework(sourceFramework, destinationFrameworks.join(framework), force, symlink);
                    found = true;
                    break;
                }
            }

            if (!found)
                warn("Couldn't find the framework: " + logPath(framework));

            for (var i = 0, found = false; i < OBJJ.objj_debug_frameworks.length; i++)
            {
                var sourceDebugFramework = node_path.join(OBJJ.objj_debug_frameworks[i], framework);
                
                if (fs.lstatSync(sourceDebugFramework).isDirectory())
                {
                    installFramework(sourceDebugFramework, destinationDebugFrameworks.join(framework), force, symlink);
                    found = true;
                    break;
                }
            }

            if (!found)
                warn("Couldn't find the debug framework: " + logPath(framework));
        });
    }
}

function installFramework(source, dest, force, symlink)
{
    if (dest.exists())
    {
        if (force)
            dest.rmtree();

        else
        {
            warn(logPath(dest) + " already exists. Use --force to overwrite.");
            return;
        }
    }

    if (source.exists())
    {
        stream.print((symlink ? "Symlinking " : "Copying ") + logPath(source) + " ==> " + logPath(dest));

        if (symlink)
            fs.symlinkSync(source, dest);
        else
            copyRecursiveSync(source, dest);
    }
    else
        warn("Cannot find: " + logPath(source));
}

function createThemesInFile(/*Array*/ themes, /*String*/ aFile, /*Boolean*/ symlink, /*Boolean*/ force)
{
    var destination = node_path.resolve(aFile);

    if (!destination.isDirectory())
        fail("Cannot create Themes. The directory does not exist: " + destination);

    var destinationThemes = destination.join("Resources");

    stream.print("Creating Themes in " + logPath(destinationThemes) + "...");

    if (!(process.env["CAPP_BUILD"]))
        fail("$CAPP_BUILD must be defined to use the --theme or -T option.");

    var themesBuild = node_path.join(process.env["CAPP_BUILD"], "Release"),
        sources = [];

    themes.forEach(function(theme)
    {
        var themeFolder = theme + ".blend",
            path = node_path.join(themesBuild, themeFolder);
        
        if (!fs.lstatSync(path).isDirectory())
            fail("Cannot find theme " + themeFolder + " in " + themesBuild);

        sources.push([path, themeFolder])
    });

    sources.forEach(function(source)
    {
        installTheme(source[0], node_path.join(destinationThemes, source[1]), force, symlink);
    });
}

function installTheme(source, dest, force, symlink)
{
    if (dest.exists())
    {
        if (force)
            dest.rmtree();

        else
        {
            warn(logPath(dest) + " already exists. Use --force to overwrite.");
            return;
        }
    }

    if (source.exists())
    {
        stream.print((symlink ? "Symlinking " : "Copying ") + logPath(source) + " ==> " + logPath(dest));

        if (symlink)
            fs.symlinkSync(source, dest);
        else
            copyRecursiveSync(source, dest);
    }
    else
        warn("Cannot find: " + logPath(source));
}

function toIdentifier(/*String*/ aString)
{
    var identifier = "",
        count = aString.length,
        capitalize = NO,
        firstRegex = new RegExp("^[a-zA-Z_$]"),
        regex = new RegExp("^[a-zA-Z_$0-9]");

    for (var index = 0; index < count; ++index)
    {
        var character = aString.charAt(index);

        if ((index === 0) && firstRegex.test(character) || regex.test(character))
        {
            if (capitalize)
                identifier += character.toUpperCase();
            else
                identifier += character;

            capitalize = NO;
        }
        else
            capitalize = YES;
    }

    return identifier;
}

function listTemplates()
{
    fs.readdirSync(templatesDirectory).forEach(function(templateName)
    {
        stream.print(templateName);
    });
}

function listFrameworks()
{
    stream.print("Frameworks:");

    OBJJ.objj_frameworks.forEach(function(frameworksDirectory)
    {
        stream.print("  " + frameworksDirectory);

        fs.readdirSync(frameworksDirectory).forEach(function(templateName)
        {
            stream.print("    + " + templateName);
        });
    });

    stream.print("Frameworks (Debug):");

    OBJJ.objj_debug_frameworks.forEach(function(frameworksDirectory)
    {
        stream.print("  " + frameworksDirectory);

        fs.readdirSync(frameworksDirectory).forEach(function(frameworkName)
        {
            stream.print("    + " + frameworkName);
        });
    });
}

function executePostInstallScript(/*String*/ destinationProject)
{
    var path = node_path.join(destinationProject, "postinstall");
    
    if (fs.existsSync(path))
    {
        stream.print(colorize("Executing postinstall script...", "cyan"));
        child_process.execSync("/bin/sh" + " " + path + " " + destinationProject);
        //OS.system(["/bin/sh", path, destinationProject]);  // Use sh in case it isn't marked executable
        fs.rmSync(path);
    }
}

function colorize(message, color)
{
    return "\0" + color + "(" + message + "\0)";
}

function logPath(path)
{
    return colorize(path, "cyan");
}

function warn(message)
{
    stream.print(colorize("Warning: ", "yellow") + message);
}

function fail(message)
{
    stream.print(colorize(message, "red"));
    process.exit(1);
}
