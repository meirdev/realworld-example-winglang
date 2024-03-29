const validator = require("email-validator");
const slugify = require("slugify");

exports.emailValidator = validator.validate;

exports.slugify = slugify;

exports.parseInt = parseInt;

exports.sorted = (a) => a.toSorted();
